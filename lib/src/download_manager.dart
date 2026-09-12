import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'download_task.dart';
import 'history.dart';
import 'hooks.dart';
import 'models.dart';
import 'store.dart';

class DownloadManager {
  final TaskStore store;
  final int maxConcurrentTasks;
  final String? downloadDir;
  final List<DownloadRule> rules;
  final Map<String, String> onCompleteAliases;
  final bool notifications;
  final HistoryLog history;
  final Map<String, TaskRecord> _records = {};
  final Map<String, DownloadTask> _active = {};
  final Map<String, DateTime> _startedAt = {};
  final List<String> _queue = [];
  final _controller = StreamController<TaskRecord>.broadcast();
  final SpeedLimiter? _globalLimiter;
  Timer? _scheduleTimer;
  DownloadManager({
    TaskStore? store,
    this.maxConcurrentTasks = 3,
    this.downloadDir,
    this.rules = const [],
    this.onCompleteAliases = const {},
    this.notifications = false,
    int? globalSpeedLimitBytesPerSec,
    HistoryLog? history,
  })  : store = store ?? TaskStore(),
        history = history ?? HistoryLog(),
        _globalLimiter = globalSpeedLimitBytesPerSec != null
            ? SpeedLimiter(globalSpeedLimitBytesPerSec)
            : null {
    for (final record in this.store.load()) {
      if (record.status == DownloadStatus.downloading ||
          record.status == DownloadStatus.probing) {
        record.status = DownloadStatus.paused;
      }
      final schedule = record.schedule;
      if (record.status == DownloadStatus.scheduled &&
          schedule != null &&
          schedule.onStartup) {
        record.status = DownloadStatus.queued;
      }
      _records[record.id] = record;
    }
    for (final record in _records.values) {
      if (record.status == DownloadStatus.queued &&
          !_queue.contains(record.id)) {
        _queue.add(record.id);
      }
    }
    _scheduleTimer = Timer.periodic(
      const Duration(seconds: 1),
      _checkSchedules,
    );
    _pump();
  }
  Stream<TaskRecord> get events => _controller.stream;
  List<TaskRecord> get tasks => _records.values.toList();
  TaskRecord? get(String id) => _records[id];
  void _persist() => store.save(_records.values.toList());
  void _emit(TaskRecord record) {
    record.updatedAt = DateTime.now();
    _controller.add(record);
    _persist();
  }

  DownloadRule? _matchRule(String url) {
    for (final rule in rules) {
      if (rule.matches(url)) return rule;
    }
    return null;
  }

  TaskRecord? _findDuplicate(String url, String savePath) {
    for (final record in _records.values) {
      if (record.status == DownloadStatus.completed ||
          record.status == DownloadStatus.canceled) {
        continue;
      }
      if (record.url == url || record.savePath == savePath) return record;
    }
    return null;
  }

  TaskRecord add(
    String url, {
    String? savePath,
    TaskOptions options = const TaskOptions(),
    bool startPaused = false,
    Schedule? schedule,
    bool allowDuplicate = false,
  }) {
    final rule = _matchRule(url);
    final effectiveOptions = rule != null ? options.mergeRule(rule) : options;
    final path = savePath ?? _inferSavePath(url, ruleDir: rule?.saveDir);
    if (!allowDuplicate) {
      final dup = _findDuplicate(url, path);
      if (dup != null) {
        throw StateError(
          'Duplicate of existing task ${dup.id} (same url or save path)',
        );
      }
    }
    final id = _generateId();
    final hasSchedule = schedule != null && schedule.isSet;
    final record = TaskRecord(
      id: id,
      url: url,
      savePath: path,
      options: effectiveOptions,
      startPaused: startPaused,
      status: hasSchedule
          ? DownloadStatus.scheduled
          : (startPaused ? DownloadStatus.paused : DownloadStatus.queued),
      schedule: hasSchedule ? schedule : null,
    );
    _records[id] = record;
    _emit(record);
    if (!hasSchedule && !startPaused) _enqueue(id);
    return record;
  }

  String _inferSavePath(String url, {String? ruleDir}) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final name = segments.isNotEmpty && segments.last.isNotEmpty
        ? segments.last
        : 'download';
    final dir = ruleDir ?? downloadDir;
    if (dir == null || dir.isEmpty) return name;
    final sep = dir.endsWith('/') ? '' : '/';
    return '$dir$sep$name';
  }

  String _generateId() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _checkSchedules(Timer timer) {
    final now = DateTime.now();
    for (final record in _records.values.toList()) {
      if (record.status != DownloadStatus.scheduled) continue;
      final schedule = record.schedule;
      if (schedule == null || schedule.onStartup) continue;
      final at = schedule.at;
      if (at != null && !now.isBefore(at)) {
        record.status = DownloadStatus.queued;
        _emit(record);
        _enqueue(record.id);
      }
    }
  }

  void _rescheduleIfRecurring(TaskRecord record) {
    final every = record.schedule?.every;
    if (every == null) return;
    record.status = DownloadStatus.scheduled;
    record.schedule = Schedule(at: DateTime.now().add(every), every: every);
    record.segments = [];
    record.totalBytes = null;
    record.error = null;
    _emit(record);
  }

  void _enqueue(String id) {
    if (!_queue.contains(id)) _queue.add(id);
    _pump();
  }

  String? _nextQueuedId() {
    String? best;
    var bestPriority = -1 << 30;
    for (final id in _queue) {
      final record = _records[id];
      if (record == null) continue;
      final priority = record.options.priority;
      if (priority > bestPriority) {
        bestPriority = priority;
        best = id;
      }
    }
    return best;
  }

  void _pump() {
    while (_active.length < maxConcurrentTasks && _queue.isNotEmpty) {
      final id = _nextQueuedId();
      if (id == null) break;
      _queue.remove(id);
      final record = _records[id];
      if (record == null) continue;
      if (record.status == DownloadStatus.canceled) continue;
      _startTask(record);
    }
  }

  void _startTask(TaskRecord record) {
    final task = DownloadTask(record);
    _startedAt[record.id] = DateTime.now();
    task.onStateChanged = () => _emit(record);
    task.onProgress = (_, __) => _emit(record);
    _active[record.id] = task;
    task.run(globalLimiter: _globalLimiter).whenComplete(() {
      _active.remove(record.id);
      final startedAt = _startedAt.remove(record.id) ?? DateTime.now();
      _emit(record);
      _handleTaskFinished(record, startedAt);
      _pump();
    });
  }

  void _handleTaskFinished(TaskRecord record, DateTime startedAt) {
    final finished = record.status == DownloadStatus.completed ||
        record.status == DownloadStatus.failed;
    if (finished) {
      history.append(
        HistoryEntry(
          id: record.id,
          url: record.url,
          savePath: record.savePath,
          status: record.status,
          totalBytes: record.downloadedBytes,
          durationMs: DateTime.now().difference(startedAt).inMilliseconds,
          finishedAt: DateTime.now(),
        ),
      );
      final hook = record.options.onComplete;
      if (hook != null && hook.isNotEmpty) {
        unawaited(
          runOnComplete(
            hook,
            onCompleteAliases,
            taskId: record.id,
            url: record.url,
            savePath: record.savePath,
            status: record.status.name,
          ),
        );
      }
      if (notifications) {
        unawaited(
          sendNotification(
            record.status == DownloadStatus.completed
                ? 'Download complete'
                : 'Download failed',
            record.savePath,
          ),
        );
      }
    }
    if (record.status == DownloadStatus.completed) {
      _rescheduleIfRecurring(record);
    }
  }

  Future<void> start(String id) async {
    final record = _records[id];
    if (record == null) throw ArgumentError('Unknown task id "$id"');
    if (record.status == DownloadStatus.completed) return;
    record.status = DownloadStatus.queued;
    _emit(record);
    _enqueue(id);
  }

  Future<void> pause(String id) async {
    final task = _active[id];
    if (task != null) {
      await task.pause();
      return;
    }
    final record = _records[id];
    if (record != null &&
        (record.status == DownloadStatus.queued ||
            record.status == DownloadStatus.scheduled)) {
      _queue.remove(id);
      record.status = DownloadStatus.paused;
      _emit(record);
    }
  }

  Future<void> cancel(String id) async {
    final task = _active[id];
    if (task != null) {
      await task.cancel();
      return;
    }
    _queue.remove(id);
    final record = _records[id];
    if (record != null) {
      record.status = DownloadStatus.canceled;
      _emit(record);
    }
  }

  Future<void> remove(String id, {bool deleteFile = false}) async {
    if (_active.containsKey(id)) {
      await cancel(id);
    }
    _queue.remove(id);
    final record = _records[id];
    if (record != null) {
      record.status = DownloadStatus.canceled;
      _emit(record);
      _records.remove(id);
      if (deleteFile) {
        try {
          final f = File(record.savePath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      _persist();
    }
  }

  void dispose() {
    _scheduleTimer?.cancel();
    _controller.close();
  }
}

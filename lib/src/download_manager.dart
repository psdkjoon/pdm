import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'download_task.dart';
import 'models.dart';
import 'store.dart';

/// Top-level entry point for the library. Owns the task list, persists it,
/// and runs downloads with a bounded number of concurrent tasks.
class DownloadManager {
  final TaskStore store;
  final int maxConcurrentTasks;
  final int defaultConnections;

  final Map<String, TaskRecord> _records = {};
  final Map<String, DownloadTask> _active = {};
  final _rand = Random();

  final _events = StreamController<TaskRecord>.broadcast();

  /// Fires on every state/progress change for any task.
  Stream<TaskRecord> get events => _events.stream;

  DownloadManager({
    TaskStore? store,
    this.maxConcurrentTasks = 3,
    this.defaultConnections = 4,
  }) : store = store ?? TaskStore.defaultLocation() {
    for (final r in this.store.loadAll()) {
      if (r.status == DownloadStatus.downloading ||
          r.status == DownloadStatus.probing) {
        r.status = DownloadStatus.paused;
      }
      _records[r.id] = r;
    }
  }

  List<TaskRecord> list() =>
      _records.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  TaskRecord? get(String id) => _records[id];

  String _newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String id;
    do {
      id = List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
    } while (_records.containsKey(id));
    return id;
  }

  /// Register a new download. Doesn't start it — call [start] (or [startAll]).
  TaskRecord add(String url, {String? savePath, int? connections}) {
    final id = _newId();
    final path = savePath ?? _guessFileName(url);
    final record = TaskRecord(
      id: id,
      url: url,
      savePath: path,
      connections: connections ?? defaultConnections,
    );
    _records[id] = record;
    _persist();
    return record;
  }

  String _guessFileName(String url) {
    final uri = Uri.parse(url);
    final last = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'download';
    final name = last.isEmpty ? 'download' : last;
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/Downloads/$name';
  }

  Future<void> start(String id) async {
    final record = _records[id];
    if (record == null) throw ArgumentError('No task with id $id');
    if (_active.containsKey(id)) return;
    if (record.status == DownloadStatus.completed) return;

    while (_active.length >= maxConcurrentTasks) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    final task = DownloadTask(record);
    _active[id] = task;
    task.onProgress = (_, __) {
      record.updatedAt = DateTime.now();
      _events.add(record);
    };
    task.onStateChanged = () {
      record.updatedAt = DateTime.now();
      _persist();
      _events.add(record);
    };

    await task.run();
    _active.remove(id);
    _persist();
  }

  Future<void> startAll() async {
    final ids = _records.values
        .where(
          (r) =>
              r.status == DownloadStatus.queued ||
              r.status == DownloadStatus.paused,
        )
        .map((r) => r.id)
        .toList();
    await Future.wait(ids.map(start));
  }

  Future<void> pause(String id) async {
    final task = _active[id];
    if (task != null) {
      await task.pause();
      _active.remove(id);
    }
    _persist();
  }

  Future<void> cancel(String id) async {
    final task = _active[id];
    if (task != null) {
      await task.cancel();
      _active.remove(id);
    } else {
      final r = _records[id];
      if (r != null) r.status = DownloadStatus.canceled;
    }
    _persist();
  }

  Future<void> remove(String id, {bool deleteFile = false}) async {
    await cancel(id);
    final record = _records.remove(id);
    if (deleteFile && record != null) {
      final f = File(record.savePath);
      if (f.existsSync()) f.deleteSync();
    }
    _persist();
  }

  void _persist() => store.saveAll(_records.values.toList());

  Future<void> dispose() async {
    for (final task in _active.values) {
      await task.pause();
    }
    _events.close();
  }
}

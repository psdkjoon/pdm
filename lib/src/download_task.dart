import 'dart:async';
import 'dart:io';

import 'models.dart';

/// Runs a single [TaskRecord] to completion: probes the server, splits the
/// file into byte-range segments, downloads them concurrently, and writes
/// each segment directly into its final offset in the destination file
/// (no separate merge step — the file is pre-sized with [RandomAccessFile]).
class DownloadTask {
  final TaskRecord record;
  final HttpClient client;

  /// Called whenever bytes land, with (downloadedBytes, totalBytes?).
  void Function(int downloaded, int? total)? onProgress;
  void Function()? onStateChanged;

  bool _pauseRequested = false;
  bool _cancelRequested = false;
  final List<StreamSubscription<List<int>>> _subs = [];
  RandomAccessFile? _raf;
  Completer<void>? _done;

  DownloadTask(this.record, {HttpClient? client})
    : client = client ?? HttpClient();

  /// HEAD (falls back to ranged GET) to learn size + whether the server
  /// honors `Range` requests.
  Future<void> probe() async {
    record.status = DownloadStatus.probing;
    onStateChanged?.call();
    try {
      var req = await client.headUrl(Uri.parse(record.url));
      var resp = await req.close();
      await resp.drain<void>();

      int? length = resp.contentLength >= 0 ? resp.contentLength : null;
      bool ranges = resp.headers.value('accept-ranges') == 'bytes';

      if (length == null || !ranges) {
        final req2 = await client.getUrl(Uri.parse(record.url));
        req2.headers.set('Range', 'bytes=0-0');
        final resp2 = await req2.close();
        await resp2.drain<void>();
        if (resp2.statusCode == 206) {
          ranges = true;
          final cr = resp2.headers.value('content-range');
          final match = RegExp(r'/(\d+)$').firstMatch(cr ?? '');
          if (match != null) length = int.parse(match.group(1)!);
        } else if (length == null) {
          length = resp2.contentLength >= 0 ? resp2.contentLength : null;
        }
      }

      record.totalBytes = length;
      record.supportsRange = ranges && length != null;
    } catch (e) {
      record.supportsRange = false;
    }
  }

  void _buildSegmentsIfNeeded() {
    if (record.segments.isNotEmpty) return;

    if (record.supportsRange && record.totalBytes != null) {
      final total = record.totalBytes!;
      final n = record.connections.clamp(1, 32).toInt();
      final chunk = total ~/ n;
      final segments = <Segment>[];
      var start = 0;
      for (var i = 0; i < n; i++) {
        final end = (i == n - 1) ? total - 1 : start + chunk - 1;
        if (start > end) break;
        segments.add(Segment(index: i, start: start, end: end));
        start = end + 1;
      }
      record.segments = segments;
    } else {
      record.segments = [
        Segment(index: 0, start: 0, end: (record.totalBytes ?? 1) - 1),
      ];
    }
  }

  /// Begin/resume downloading. Completes when finished, paused, canceled,
  /// or failed (check [record.status] afterwards).
  Future<void> run() async {
    _pauseRequested = false;
    _cancelRequested = false;
    _done = Completer<void>();

    if (record.totalBytes == null && record.status == DownloadStatus.queued) {
      await probe();
    }
    _buildSegmentsIfNeeded();

    final destFile = File(record.savePath);
    destFile.parent.createSync(recursive: true);
    _raf = destFile.openSync(mode: FileMode.write);
    if (record.totalBytes != null) {
      _raf!.setPositionSync(record.totalBytes! - 1);
      _raf!.writeByteSync(0);
    }

    record.status = DownloadStatus.downloading;
    onStateChanged?.call();

    final futures = record.segments
        .where((s) => !s.isComplete)
        .map((s) => _runSegment(s));

    try {
      await Future.wait(futures);
    } catch (_) {}

    await _raf?.close();
    _raf = null;

    if (_cancelRequested) {
      record.status = DownloadStatus.canceled;
    } else if (_pauseRequested) {
      record.status = DownloadStatus.paused;
    } else if (record.segments.every((s) => s.isComplete)) {
      record.status = DownloadStatus.completed;
    } else {
      record.status = DownloadStatus.failed;
      record.error ??= 'Incomplete download';
    }
    onStateChanged?.call();
    _done!.complete();
  }

  Future<void> _runSegment(Segment seg) async {
    if (_cancelRequested || _pauseRequested) return;
    try {
      final req = await client.getUrl(Uri.parse(record.url));
      if (record.supportsRange) {
        final rangeStart = seg.start + seg.downloaded;
        req.headers.set('Range', 'bytes=$rangeStart-${seg.end}');
      }
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        throw HttpException('HTTP ${resp.statusCode} for segment ${seg.index}');
      }

      var writePos = seg.start + seg.downloaded;
      final completer = Completer<void>();
      late StreamSubscription<List<int>> sub;
      sub = resp.listen(
        (chunk) {
          if (_cancelRequested || _pauseRequested) {
            sub.cancel();
            if (!completer.isCompleted) completer.complete();
            return;
          }
          sub.pause();
          _raf!.setPositionSync(writePos);
          _raf!.writeFromSync(chunk);
          writePos += chunk.length;
          seg.downloaded += chunk.length;
          onProgress?.call(record.downloadedBytes, record.totalBytes);
          sub.resume();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e) {
          record.error = e.toString();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      _subs.add(sub);
      await completer.future;
    } catch (e) {
      record.error = e.toString();
    }
  }

  /// Signal all in-flight segment requests to stop; current progress is
  /// preserved in `record.segments[*].downloaded` for a later [run] to resume.
  Future<void> pause() async {
    _pauseRequested = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _done?.future;
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _done?.future;
    try {
      final f = File(record.savePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

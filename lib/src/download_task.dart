import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cookies.dart';
import 'diskspace.dart';
import 'hashing.dart';
import 'models.dart';

class DownloadTask {
  final TaskRecord record;
  final HttpClient client;
  void Function(int downloaded, int? total)? onProgress;
  void Function()? onStateChanged;
  bool _pauseRequested = false;
  bool _cancelRequested = false;
  final List<StreamSubscription<List<int>>> _subs = [];
  final List<Completer<bool>> _pendingSegmentCompleters = [];
  RandomAccessFile? _raf;
  Completer<void>? _done;
  String? _cookieHeader;
  DownloadTask(this.record, {HttpClient? client})
    : client = client ?? HttpClient() {
    this.client.maxConnectionsPerHost = record.options.connections + 2;
    this.client.connectionTimeout = Duration(
      seconds: record.options.timeoutSeconds,
    );
    if (record.options.insecure) {
      this.client.badCertificateCallback = (cert, host, port) => true;
    }
    final proxySpec = record.options.proxy;
    if (proxySpec != null && proxySpec.isNotEmpty) {
      final proxyUri = Uri.parse(proxySpec);
      final bypass = record.options.proxyBypass;
      this.client.findProxy = (uri) {
        final bypassed = bypass.any(
          (h) => uri.host == h || uri.host.endsWith('.$h'),
        );
        return bypassed ? 'DIRECT' : 'PROXY ${proxyUri.host}:${proxyUri.port}';
      };
      final proxyUser = record.options.proxyUser;
      if (proxyUser != null) {
        final proxyPass = record.options.proxyPass ?? '';
        this.client.authenticateProxy = (host, port, scheme, realm) async {
          this.client.addProxyCredentials(
            host,
            port,
            realm ?? '',
            HttpClientBasicCredentials(proxyUser, proxyPass),
          );
          return true;
        };
      }
    }
    _cookieHeader = resolveCookieHeader(
      cookie: record.options.cookie,
      cookieFile: record.options.cookieFile,
    );
  }
  void _applyRequestHeaders(HttpClientRequest req) {
    req.maxRedirects = record.options.maxRedirects;
    for (final entry in record.options.headers.entries) {
      req.headers.set(entry.key, entry.value);
    }
    if (record.options.userAgent != null) {
      req.headers.set(HttpHeaders.userAgentHeader, record.options.userAgent!);
    }
    if (record.options.referer != null) {
      req.headers.set(HttpHeaders.refererHeader, record.options.referer!);
    }
    if (_cookieHeader != null) {
      req.headers.set(HttpHeaders.cookieHeader, _cookieHeader!);
    }
    if (record.options.authUser != null) {
      final pass = record.options.authPass ?? '';
      final creds = base64Encode(
        utf8.encode('${record.options.authUser}:$pass'),
      );
      req.headers.set(HttpHeaders.authorizationHeader, 'Basic $creds');
    }
  }

  Future<void> probe() async {
    record.status = DownloadStatus.probing;
    onStateChanged?.call();
    try {
      final req = await client.headUrl(Uri.parse(record.url));
      _applyRequestHeaders(req);
      final resp = await req.close();
      await resp.drain<void>();
      int? length = resp.contentLength >= 0 ? resp.contentLength : null;
      bool ranges = resp.headers.value('accept-ranges') == 'bytes';
      if (length == null || !ranges) {
        final req2 = await client.getUrl(Uri.parse(record.url));
        _applyRequestHeaders(req2);
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
    final totalBytes = record.totalBytes;
    if (record.supportsRange && totalBytes != null && totalBytes > 0) {
      record.segments = _splitIntoSegments(
        totalBytes: totalBytes,
        requestedSegmentCount: record.options.connections.clamp(1, 32),
      );
    } else {
      record.segments = [
        Segment(index: 0, start: 0, end: (totalBytes ?? 1) - 1),
      ];
    }
  }

  List<Segment> _splitIntoSegments({
    required int totalBytes,
    required int requestedSegmentCount,
  }) {
    final segmentCount = requestedSegmentCount > totalBytes
        ? totalBytes
        : requestedSegmentCount;
    final baseSegmentLength = totalBytes ~/ segmentCount;
    final segmentsWithExtraByte = totalBytes % segmentCount;
    final segments = <Segment>[];
    var start = 0;
    for (var i = 0; i < segmentCount; i++) {
      final segmentLength =
          baseSegmentLength + (i < segmentsWithExtraByte ? 1 : 0);
      final end = start + segmentLength - 1;
      segments.add(Segment(index: i, start: start, end: end));
      start = end + 1;
    }
    return segments;
  }

  Future<void> run({SpeedLimiter? globalLimiter}) async {
    _pauseRequested = false;
    _cancelRequested = false;
    _done = Completer<void>();
    final destFile = File(record.savePath);
    final isResume = record.segments.isNotEmpty;
    if (record.options.overwrite &&
        record.segments.isEmpty &&
        destFile.existsSync()) {
      destFile.deleteSync();
    }
    if (record.totalBytes == null && record.status == DownloadStatus.queued) {
      await probe();
    }
    _buildSegmentsIfNeeded();
    if (record.options.checkDiskSpace && record.totalBytes != null) {
      final needed = record.totalBytes! - record.downloadedBytes;
      if (needed > 0) {
        final free = await availableDiskSpace(destFile.parent.path);
        if (free != null && free < needed) {
          record.status = DownloadStatus.failed;
          record.error =
              'Not enough disk space: need $needed bytes, have $free';
          onStateChanged?.call();
          _done!.complete();
          return;
        }
      }
    }
    destFile.parent.createSync(recursive: true);
    _raf = destFile.openSync(mode: isResume ? FileMode.append : FileMode.write);
    if (!isResume && record.totalBytes != null && record.totalBytes! > 0) {
      _raf!.setPositionSync(record.totalBytes! - 1);
      _raf!.writeByteSync(0);
    }
    record.status = DownloadStatus.downloading;
    onStateChanged?.call();
    final limiter = record.options.speedLimitBytesPerSec != null
        ? SpeedLimiter(record.options.speedLimitBytesPerSec!)
        : null;
    final futures = record.segments
        .where((s) => !s.isComplete)
        .map((s) => _runSegmentWithRetries(s, limiter, globalLimiter));
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
      await _verifyIfRequested();
    } else {
      record.status = DownloadStatus.failed;
      record.error ??= 'Incomplete download';
    }
    onStateChanged?.call();
    _done!.complete();
  }

  Future<void> _verifyIfRequested() async {
    if (record.options.checksumAlgo == null ||
        record.options.checksumValue == null) {
      record.status = DownloadStatus.completed;
      return;
    }
    record.status = DownloadStatus.verifying;
    onStateChanged?.call();
    try {
      final ok = await verifyFileChecksum(
        record.savePath,
        record.options.checksumAlgo!,
        record.options.checksumValue!,
      );
      record.status = ok ? DownloadStatus.completed : DownloadStatus.failed;
      if (!ok) record.error = 'Checksum mismatch';
    } catch (e) {
      record.status = DownloadStatus.failed;
      record.error = 'Checksum verification error: $e';
    }
  }

  Future<void> _runSegmentWithRetries(
    Segment seg,
    SpeedLimiter? limiter,
    SpeedLimiter? globalLimiter,
  ) async {
    var attempt = 0;
    while (true) {
      if (_cancelRequested || _pauseRequested) return;
      final ok = await _runSegment(seg, limiter, globalLimiter);
      if (ok || _cancelRequested || _pauseRequested) return;
      attempt++;
      if (attempt > record.options.retries) return;
      final shift = attempt - 1 > 10 ? 10 : attempt - 1;
      final delayMs = record.options.retryBackoff
          ? record.options.retryDelayMs * (1 << shift)
          : record.options.retryDelayMs;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  Future<bool> _runSegment(
    Segment seg,
    SpeedLimiter? limiter,
    SpeedLimiter? globalLimiter,
  ) async {
    try {
      final req = await client.getUrl(Uri.parse(record.url));
      _applyRequestHeaders(req);
      if (record.supportsRange) {
        final rangeStart = seg.start + seg.downloaded;
        req.headers.set('Range', 'bytes=$rangeStart-${seg.end}');
      }
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        record.error = 'HTTP ${resp.statusCode} for segment ${seg.index}';
        await resp.drain<void>();
        return false;
      }
      var writePos = seg.start + seg.downloaded;
      final completer = Completer<bool>();
      late StreamSubscription<List<int>> sub;
      sub = resp.listen(
        (chunk) async {
          if (_cancelRequested || _pauseRequested) {
            if (!completer.isCompleted) completer.complete(true);
            await sub.cancel();
            return;
          }
          sub.pause();
          if (limiter != null) await limiter.throttle(chunk.length);
          if (globalLimiter != null) await globalLimiter.throttle(chunk.length);
          if (_cancelRequested || _pauseRequested || _raf == null) {
            if (!completer.isCompleted) completer.complete(true);
            await sub.cancel();
            return;
          }
          _raf!.setPositionSync(writePos);
          _raf!.writeFromSync(chunk);
          writePos += chunk.length;
          seg.downloaded += chunk.length;
          onProgress?.call(record.downloadedBytes, record.totalBytes);
          sub.resume();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (Object e) {
          record.error = e.toString();
          if (!completer.isCompleted) completer.complete(false);
        },
        cancelOnError: true,
      );
      _subs.add(sub);
      _pendingSegmentCompleters.add(completer);
      try {
        return await completer.future;
      } finally {
        _subs.remove(sub);
        _pendingSegmentCompleters.remove(completer);
      }
    } catch (e) {
      record.error = e.toString();
      return false;
    }
  }

  void _resolvePendingSegmentCompleters() {
    for (final completer in List<Completer<bool>>.from(
      _pendingSegmentCompleters,
    )) {
      if (!completer.isCompleted) completer.complete(true);
    }
  }

  Future<void> pause() async {
    _pauseRequested = true;
    _resolvePendingSegmentCompleters();
    final subs = List<StreamSubscription<List<int>>>.from(_subs);
    for (final s in subs) {
      await s.cancel();
    }
    _subs.clear();
    await _done?.future;
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    _resolvePendingSegmentCompleters();
    final subs = List<StreamSubscription<List<int>>>.from(_subs);
    for (final s in subs) {
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

class SpeedLimiter {
  final int bytesPerSecond;
  int _budget;
  DateTime _windowStart = DateTime.now();
  SpeedLimiter(this.bytesPerSecond) : _budget = bytesPerSecond;
  Future<void> throttle(int chunkSize) async {
    final now = DateTime.now();
    if (now.difference(_windowStart).inMilliseconds >= 1000) {
      _windowStart = now;
      _budget = bytesPerSecond;
    }
    _budget -= chunkSize;
    if (_budget < 0) {
      final waitMs = 1000 - now.difference(_windowStart).inMilliseconds;
      if (waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      _windowStart = DateTime.now();
      _budget = bytesPerSecond;
    }
  }
}

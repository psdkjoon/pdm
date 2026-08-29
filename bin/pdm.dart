import 'dart:async';
import 'dart:io';

import 'package:pdm/pdm.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(0);
  }

  final manager = DownloadManager();
  final command = args.first;
  final rest = args.skip(1).toList();

  try {
    switch (command) {
      case 'add':
        await _cmdAdd(manager, rest);
        break;
      case 'list':
      case 'ls':
        _cmdList(manager);
        break;
      case 'pause':
        await manager.pause(_requireId(rest));
        stdout.writeln('Paused ${rest.first}');
        break;
      case 'resume':
      case 'start':
        await manager.start(_requireId(rest));
        break;
      case 'cancel':
        await manager.cancel(_requireId(rest));
        stdout.writeln('Canceled ${rest.first}');
        break;
      case 'remove':
      case 'rm':
        await manager.remove(
          _requireId(rest),
          deleteFile: rest.contains('--delete-file'),
        );
        stdout.writeln('Removed ${rest.first}');
        break;
      case 'watch':
        await _cmdWatch(manager, rest);
        break;
      case '-h':
      case '--help':
      case 'help':
        _printUsage();
        break;
      case '-v':
      case '--version':
      case 'version':
        stdout.writeln('pdm ${pdmVersion()}');
        break;
      default:
        stderr.writeln('Unknown command: $command\n');
        _printUsage();
        exit(1);
    }
  } finally {
    await manager.dispose();
  }
}

String _requireId(List<String> rest) {
  if (rest.isEmpty) {
    stderr.writeln('Missing task id.');
    exit(1);
  }
  return rest.first;
}

Future<void> _cmdAdd(DownloadManager manager, List<String> rest) async {
  if (rest.isEmpty) {
    stderr.writeln(
      'Usage: pdm add <url> [-o <output-path>] [-c <connections>]',
    );
    exit(1);
  }
  final url = rest.first;
  String? output;
  int? connections;

  for (var i = 1; i < rest.length; i++) {
    switch (rest[i]) {
      case '-o':
      case '--output':
        output = rest[++i];
        break;
      case '-c':
      case '--connections':
        connections = int.tryParse(rest[++i]);
        break;
    }
  }

  final record = manager.add(url, savePath: output, connections: connections);
  stdout.writeln('Added ${record.id}  ->  ${record.savePath}');
  final done = Completer<void>();
  final sub = manager.events.where((r) => r.id == record.id).listen((r) {
    _renderProgressLine(r);
    if (r.status == DownloadStatus.completed ||
        r.status == DownloadStatus.failed ||
        r.status == DownloadStatus.canceled) {
      done.complete();
    }
  });

  unawaited(manager.start(record.id));
  await done.future;
  await sub.cancel();
  stdout.writeln();

  final finalRecord = manager.get(record.id)!;
  if (finalRecord.status == DownloadStatus.completed) {
    stdout.writeln('Done: ${finalRecord.savePath}');
  } else {
    stdout.writeln('${finalRecord.status.name}: ${finalRecord.error ?? ''}');
  }
}

void _cmdList(DownloadManager manager) {
  final tasks = manager.list();
  if (tasks.isEmpty) {
    stdout.writeln('No downloads yet. Try: pdm add <url>');
    return;
  }
  for (final t in tasks) {
    final pct = (t.progress * 100).toStringAsFixed(1);
    final size = t.totalBytes != null ? _humanSize(t.totalBytes!) : '?';
    stdout.writeln(
      '${t.id}  [${t.status.name.padRight(11)}]  $pct%  ($size)  '
      '${t.url}',
    );
    stdout.writeln('       -> ${t.savePath}');
  }
}

Future<void> _cmdWatch(DownloadManager manager, List<String> rest) async {
  final id = _requireId(rest);
  await manager.start(id);
  final sub = manager.events
      .where((r) => r.id == id)
      .listen(_renderProgressLine);
  final record = manager.get(id)!;
  while (record.status == DownloadStatus.downloading ||
      record.status == DownloadStatus.queued ||
      record.status == DownloadStatus.probing) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  await sub.cancel();
  stdout.writeln();
}

DateTime _lastTick = DateTime.now();
int _lastBytes = 0;

void _renderProgressLine(TaskRecord r) {
  final now = DateTime.now();
  final elapsedMs = now.difference(_lastTick).inMilliseconds;
  final deltaBytes = r.downloadedBytes - _lastBytes;
  final speed = elapsedMs > 0 ? (deltaBytes / (elapsedMs / 1000)) : 0.0;
  _lastTick = now;
  _lastBytes = r.downloadedBytes;

  final pct = (r.progress * 100).clamp(0, 100).toStringAsFixed(1);
  final barWidth = 30;
  final filled = (r.progress.clamp(0, 1) * barWidth).round();
  final bar = '#' * filled + '-' * (barWidth - filled);
  final total = r.totalBytes != null ? _humanSize(r.totalBytes!) : '?';
  stdout.write(
    '\r[$bar] $pct%  ${_humanSize(r.downloadedBytes)}/$total  ${_humanSize(speed.round())}/s   ',
  );
}

String _humanSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)}${units[i]}';
}

void _printUsage() {
  stdout.writeln('''
pdm ${pdmVersion()} — pure-Dart multi-connection download manager

Usage:
  pdm add <url> [-o <output-path>] [-c <connections>]   Add + start a download, watch live
  pdm list                                               List all tasks
  pdm resume <id>                                        Start/resume a task in the background
  pdm pause <id>                                         Pause a running task
  pdm cancel <id>                                        Cancel and stop a task
  pdm remove <id> [--delete-file]                        Remove task from the list
  pdm watch <id>                                         Attach a live progress view to a task
  pdm help                                                Show this help
  pdm --version                                           Show version
''');
}

import 'dart:convert';
import 'dart:io';

import '../../history.dart';
import '../../models.dart';
import '../context.dart';
import '../parser.dart';
import '../render.dart';

Future<int> runHistory(CliContext ctx, ParsedArgs args) async {
  final log = HistoryLog();
  if (args.flag('clear')) {
    log.clear();
    ctx.log(ctx.theme.success('History cleared.'));
    return 0;
  }
  final entries = log.load(limit: args.intVal('limit'));
  if (ctx.jsonOutput) {
    stdout.writeln(jsonEncode(entries.map((e) => e.toJson()).toList()));
    return 0;
  }
  if (entries.isEmpty) {
    stdout.writeln(ctx.theme.muted('No history yet.'));
    return 0;
  }
  var totalBytes = 0;
  var totalMs = 0;
  for (final e in entries) {
    totalBytes += e.downloadedBytes;
    totalMs += e.durationMs;
  }
  stdout.writeln(
    ctx.theme.bold(
      '${'FINISHED'.padRight(17)}  ${'STATUS'.padRight(10)}  ${'SIZE'.padRight(9)}  ${'SPEED'.padRight(11)}  NAME',
    ),
  );
  for (final e in entries) {
    final name = basename(e.savePath);
    final speed = e.averageBytesPerSec > 0
        ? formatSpeed(e.averageBytesPerSec.round())
        : '-';
    final statusText = e.status.name.padRight(10);
    final statusColored = e.status == DownloadStatus.completed
        ? ctx.theme.success(statusText)
        : ctx.theme.error(statusText);
    stdout.writeln(
      '${_formatTime(e.finishedAt).padRight(17)}  $statusColored  ${formatBytes(e.downloadedBytes).padRight(9)}  ${speed.padRight(11)}  $name',
    );
  }
  final avgSpeed = totalMs > 0
      ? formatSpeed((totalBytes / (totalMs / 1000)).round())
      : '-';
  stdout.writeln();
  stdout.writeln(
    'Total: ${formatBytes(totalBytes)} across ${entries.length} task(s), avg speed $avgSpeed',
  );
  return 0;
}

String _formatTime(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

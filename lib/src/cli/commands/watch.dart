import 'dart:async';
import 'dart:io';

import '../../models.dart';
import '../context.dart';
import '../parser.dart';
import '../render.dart';

Future<int> runWatch(CliContext ctx, ParsedArgs args) async {
  if (args.positionals.isEmpty) {
    stderr.writeln('Usage: pdm watch <id> [flags]');
    return 1;
  }
  final id = args.positionals.first;
  final noBar = args.flag('no-bar');
  final intervalMs = args.intVal('interval') ?? 200;
  await ctx.client.connect(allowSpawn: ctx.allowSpawn);
  var lastBytes = 0;
  var lastTime = DateTime.now();
  final completer = Completer<int>();
  final sub = ctx.client.watch(id).listen(
    (event) {
      final record = TaskRecord.fromJson(event.task);
      final now = DateTime.now();
      final elapsed = now.difference(lastTime).inMilliseconds;
      final terminal = record.status == DownloadStatus.completed ||
          record.status == DownloadStatus.failed ||
          record.status == DownloadStatus.canceled;
      if (elapsed < intervalMs && !terminal) return;
      int? speed;
      if (elapsed > 0) {
        speed =
            ((record.downloadedBytes - lastBytes) / (elapsed / 1000)).round();
      }
      lastBytes = record.downloadedBytes;
      lastTime = now;
      if (noBar) {
        final pct = (record.progress * 100).toStringAsFixed(1);
        stdout.writeln(
          '${record.status.name}  $pct%  ${formatBytes(record.downloadedBytes)}',
        );
      } else {
        printProgressLine(record, ctx.theme, bytesPerSecond: speed);
      }
      if (record.status == DownloadStatus.completed) {
        if (!noBar) stdout.writeln();
        ctx.log(ctx.theme.success('Completed: ${record.savePath}'));
        if (!completer.isCompleted) completer.complete(0);
      } else if (record.status == DownloadStatus.failed) {
        if (!noBar) stdout.writeln();
        stderr.writeln(
          ctx.theme.error('Failed: ${record.error ?? "unknown error"}'),
        );
        if (!completer.isCompleted) completer.complete(1);
      } else if (record.status == DownloadStatus.canceled) {
        if (!noBar) stdout.writeln();
        ctx.log(ctx.theme.warn('Canceled'));
        if (!completer.isCompleted) completer.complete(1);
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        stderr.writeln(
          ctx.theme.error('Lost connection to the pdm daemon'),
        );
        completer.complete(1);
      }
    },
    onError: (Object e) {
      if (!completer.isCompleted) {
        stderr.writeln(ctx.theme.error('Watch error: $e'));
        completer.complete(1);
      }
    },
  );
  final exitCode = await completer.future;
  await sub.cancel();
  await ctx.client.close();
  return exitCode;
}

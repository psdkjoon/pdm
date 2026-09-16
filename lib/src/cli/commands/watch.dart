import 'dart:async';
import 'dart:collection';
import 'dart:io';

import '../../daemon/daemon_client.dart';
import '../../models.dart';
import '../context.dart';
import '../parser.dart';
import '../render.dart';

Future<int> runWatch(CliContext ctx, ParsedArgs args) async {
  if (args.positionals.isEmpty) {
    stderr.writeln('Usage: pdm watch <id> [<id> ...] [flags]');
    return 1;
  }
  final ids = LinkedHashSet<String>.from(args.positionals).toList();
  final noBar = args.flag('no-bar') || ids.length > 1;
  final intervalMs = args.intVal('interval') ?? 200;
  if (ids.length == 1) {
    await ctx.client.connect(allowSpawn: ctx.allowSpawn);
    final code = await _watchOne(
      ctx,
      ctx.client,
      ids.single,
      noBar: noBar,
      intervalMs: intervalMs,
      prefix: null,
    );
    await ctx.client.close();
    return code;
  }
  final clients = [
    for (var i = 0; i < ids.length; i++) DaemonClient(ctx.client.address),
  ];
  for (final client in clients) {
    await client.connect(allowSpawn: ctx.allowSpawn);
  }
  final results = await Future.wait([
    for (var i = 0; i < ids.length; i++)
      _watchOne(
        ctx,
        clients[i],
        ids[i],
        noBar: noBar,
        intervalMs: intervalMs,
        prefix: ids[i],
      ),
  ]);
  await Future.wait(clients.map((c) => c.close()));
  return results.every((c) => c == 0) ? 0 : 1;
}

Future<int> _watchOne(
  CliContext ctx,
  DaemonClient client,
  String id, {
  required bool noBar,
  required int intervalMs,
  required String? prefix,
}) async {
  var lastBytes = 0;
  var lastTime = DateTime.now();
  final completer = Completer<int>();
  final tag = prefix == null ? '' : '[$prefix] ';
  final sub = client
      .watch(id)
      .listen(
        (event) {
          final record = TaskRecord.fromJson(event.task);
          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          final terminal =
              record.status == DownloadStatus.completed ||
              record.status == DownloadStatus.failed ||
              record.status == DownloadStatus.canceled;
          if (elapsed < intervalMs && !terminal) return;
          int? speed;
          if (elapsed > 0) {
            speed = ((record.downloadedBytes - lastBytes) / (elapsed / 1000))
                .round();
          }
          lastBytes = record.downloadedBytes;
          lastTime = now;
          if (noBar) {
            final pct = (record.progress * 100).toStringAsFixed(1);
            stdout.writeln(
              '$tag${record.status.name}  $pct%  ${formatBytes(record.downloadedBytes)}',
            );
          } else {
            printProgressLine(record, ctx.theme, bytesPerSecond: speed);
          }
          if (record.status == DownloadStatus.completed) {
            if (!noBar) stdout.writeln();
            ctx.log(ctx.theme.success('${tag}Completed: ${record.savePath}'));
            if (!completer.isCompleted) completer.complete(0);
          } else if (record.status == DownloadStatus.failed) {
            if (!noBar) stdout.writeln();
            stderr.writeln(
              ctx.theme.error(
                '${tag}Failed: ${record.error ?? "unknown error"}',
              ),
            );
            if (!completer.isCompleted) completer.complete(1);
          } else if (record.status == DownloadStatus.canceled) {
            if (!noBar) stdout.writeln();
            ctx.log(ctx.theme.warn('${tag}Canceled'));
            if (!completer.isCompleted) completer.complete(1);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            stderr.writeln(
              ctx.theme.error('${tag}Lost connection to the pdm daemon'),
            );
            completer.complete(1);
          }
        },
        onError: (Object e) {
          if (!completer.isCompleted) {
            stderr.writeln(ctx.theme.error('${tag}Watch error: $e'));
            completer.complete(1);
          }
        },
      );
  final exitCode = await completer.future;
  await sub.cancel();
  return exitCode;
}

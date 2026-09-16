import 'dart:collection';
import 'dart:io';

import '../../models.dart';
import '../context.dart';
import '../parser.dart';

Future<int> runTaskAction(
  CliContext ctx,
  ParsedArgs args,
  String action, {
  bool supportsDeleteFile = false,
}) async {
  await ctx.client.connect(allowSpawn: ctx.allowSpawn);
  List<String> ids;
  if (args.flag('all')) {
    final listResp = await ctx.client.request('list');
    if (!listResp.ok) {
      stderr.writeln(ctx.theme.error('Error: ${listResp.error}'));
      await ctx.client.close();
      return 1;
    }
    ids = (listResp.data as List)
        .map((e) => TaskRecord.fromJson((e as Map).cast<String, dynamic>()))
        .where((r) => _actionApplies(action, r.status))
        .map((r) => r.id)
        .toList();
  } else {
    if (args.positionals.isEmpty) {
      stderr.writeln('Usage: pdm $action <id> [<id> ...] [flags]');
      await ctx.client.close();
      return 1;
    }
    ids = LinkedHashSet<String>.from(args.positionals).toList();
  }
  final destructive = action == 'remove' || action == 'cancel';
  if (destructive &&
      !args.flag('force') &&
      stdin.hasTerminal &&
      ids.isNotEmpty) {
    final deleteFile = supportsDeleteFile && args.flag('delete-file');
    final idList = ids.length <= 5
        ? ids.join(', ')
        : '${ids.take(5).join(', ')}, and ${ids.length - 5} more';
    final label = deleteFile
        ? '$action (and delete file) ${ids.length} task(s): $idList'
        : '$action ${ids.length} task(s): $idList';
    stdout.write('$label? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'y' && answer != 'yes') {
      ctx.log('Aborted.');
      await ctx.client.close();
      return 1;
    }
  }
  if (ids.isEmpty) {
    ctx.log('Nothing to $action.');
    await ctx.client.close();
    return 0;
  }
  var exitCode = 0;
  var okCount = 0;
  for (final id in ids) {
    final command = action == 'resume' ? 'start' : action;
    final requestArgs = <String, dynamic>{'id': id};
    if (supportsDeleteFile) {
      requestArgs['deleteFile'] = args.flag('delete-file');
    }
    final resp = await ctx.client.request(command, requestArgs);
    if (!resp.ok) {
      stderr.writeln(ctx.theme.error('$id: ${resp.error}'));
      exitCode = 1;
    } else {
      okCount++;
      ctx.log(ctx.theme.success('$id: $action ok'));
    }
  }
  if (ids.length > 1) {
    ctx.log('$okCount/${ids.length} succeeded.');
  }
  await ctx.client.close();
  return exitCode;
}

bool _actionApplies(String action, DownloadStatus status) {
  switch (action) {
    case 'pause':
      return status == DownloadStatus.downloading ||
          status == DownloadStatus.queued;
    case 'resume':
      return status == DownloadStatus.paused || status == DownloadStatus.failed;
    case 'cancel':
      return status != DownloadStatus.completed &&
          status != DownloadStatus.canceled;
    case 'remove':
      return true;
    default:
      return true;
  }
}

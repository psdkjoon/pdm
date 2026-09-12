import 'dart:async';
import 'dart:io';
import '../../config.dart';
import '../../download_manager.dart';
import '../../models.dart';
import '../context.dart';
import '../parser.dart';
import '../render.dart';
Future<int> runAdd(CliContext ctx, ParsedArgs args) async {
  final headers = <String, String>{};
  for (final h in args.multi('header')) {
    final entry = parseHeaderSpec(h);
    headers[entry.key] = entry.value;
  }
  final checksum = parseChecksumSpec(args.str('checksum'));
  final options = TaskOptions(
    connections: args.intVal('connections') ?? ctx.config.connections,
    headers: headers,
    userAgent: args.str('user-agent'),
    referer: args.str('referer'),
    cookie: args.str('cookie'),
    cookieFile: args.str('cookie-file'),
    proxy: args.str('proxy') ?? ctx.config.proxy,
    proxyUser: args.str('proxy-user') ?? ctx.config.proxyUser,
    proxyPass: args.str('proxy-pass') ?? ctx.config.proxyPass,
    proxyBypass: ctx.config.proxyBypass,
    retries: args.intVal('retries') ?? ctx.config.retries,
    retryDelayMs: args.intVal('retry-delay') ?? ctx.config.retryDelayMs,
    retryBackoff: !args.flag('linear-retries') && ctx.config.retryBackoff,
    timeoutSeconds: args.intVal('timeout') ?? ctx.config.timeoutSeconds,
    speedLimitBytesPerSec: parseByteSize(args.str('speed-limit')) ??
        ctx.config.speedLimitBytesPerSec,
    checksumAlgo: checksum?.$1,
    checksumValue: checksum?.$2,
    authUser: args.str('auth-user'),
    authPass: args.str('auth-pass'),
    insecure: args.flag('insecure') || ctx.config.insecure,
    overwrite: args.flag('overwrite'),
    priority: args.intVal('priority') ?? 0,
    maxRedirects: args.intVal('max-redirects') ?? ctx.config.maxRedirects,
    onComplete: args.str('on-complete'),
    checkDiskSpace: ctx.config.checkDiskSpace,
  );
  final schedule = _buildSchedule(args);
  final allowDuplicate = args.flag('allow-duplicate');
  final startPaused = args.flag('start-paused');
  final foreground = args.flag('foreground');
  final filePath = args.str('file');
  if (filePath != null) {
    return _runBatch(ctx, filePath, options, schedule, allowDuplicate, startPaused);
  }
  if (args.positionals.isEmpty) {
    stderr.writeln('Usage: pdm add <url> [flags]');
    return 1;
  }
  final url = args.positionals.first;
  if (foreground) {
    return _runForeground(
      ctx,
      url,
      args.str('output'),
      options,
      startPaused,
      schedule,
      allowDuplicate,
    );
  }
  return _runBackground(
    ctx,
    url,
    args.str('output'),
    options,
    startPaused,
    schedule,
    allowDuplicate,
  );
}
Schedule? _buildSchedule(ParsedArgs args) {
  final atRaw = args.str('at');
  final everyRaw = args.str('every');
  final onStartup = args.flag('on-startup');
  if (atRaw == null && everyRaw == null && !onStartup) return null;
  Duration? every;
  if (everyRaw != null) {
    every = parseDurationSpec(everyRaw);
    if (every == null) {
      throw FlagParseException('--every expects a duration like 30m, 6h, 1d');
    }
  }
  final at = atRaw != null ? parseScheduleAt(atRaw, DateTime.now()) : null;
  return Schedule(at: at, every: every, onStartup: onStartup);
}
Future<int> _runForeground(
  CliContext ctx,
  String url,
  String? output,
  TaskOptions options,
  bool startPaused,
  Schedule? schedule,
  bool allowDuplicate,
) async {
  final manager = DownloadManager(
    maxConcurrentTasks: 1,
    downloadDir: expandHome(ctx.config.downloadDir),
    rules: ctx.config.rules,
    onCompleteAliases: ctx.config.onCompleteAliases,
    notifications: ctx.config.notifications,
    globalSpeedLimitBytesPerSec: ctx.config.globalSpeedLimitBytesPerSec,
  );
  TaskRecord record;
  try {
    record = manager.add(
      url,
      savePath: output,
      options: options,
      startPaused: startPaused,
      schedule: schedule,
      allowDuplicate: allowDuplicate,
    );
  } catch (e) {
    stderr.writeln(ctx.theme.error('Error: $e'));
    manager.dispose();
    return 1;
  }
  if (record.status == DownloadStatus.scheduled) {
    ctx.log('Scheduled ${record.id} for ${record.schedule?.at ?? "next daemon startup"}.');
    manager.dispose();
    return 0;
  }
  if (startPaused) {
    ctx.log(
      'Added ${record.id} (paused). Run "pdm resume ${record.id}" to start it.',
    );
    manager.dispose();
    return 0;
  }
  var lastBytes = 0;
  var lastTime = DateTime.now();
  final completer = Completer<int>();
  manager.events.listen((r) {
    if (r.id != record.id) return;
    final now = DateTime.now();
    final elapsed = now.difference(lastTime).inMilliseconds;
    int? speed;
    if (elapsed > 200) {
      speed = ((r.downloadedBytes - lastBytes) / (elapsed / 1000)).round();
      lastBytes = r.downloadedBytes;
      lastTime = now;
    }
    if (!ctx.quiet) printProgressLine(r, ctx.theme, bytesPerSecond: speed);
    if (r.status == DownloadStatus.completed) {
      if (!ctx.quiet) stdout.writeln();
      ctx.log(ctx.theme.success('Completed: ${r.savePath}'));
      completer.complete(0);
    } else if (r.status == DownloadStatus.failed) {
      if (!ctx.quiet) stdout.writeln();
      stderr.writeln(ctx.theme.error('Failed: ${r.error ?? "unknown error"}'));
      completer.complete(1);
    } else if (r.status == DownloadStatus.canceled) {
      if (!ctx.quiet) stdout.writeln();
      ctx.log(ctx.theme.warn('Canceled'));
      completer.complete(1);
    }
  });
  final exitCode = await completer.future;
  manager.dispose();
  return exitCode;
}
Future<int> _runBackground(
  CliContext ctx,
  String url,
  String? output,
  TaskOptions options,
  bool startPaused,
  Schedule? schedule,
  bool allowDuplicate,
) async {
  await ctx.client.connect(allowSpawn: ctx.allowSpawn);
  final resp = await ctx.client.request('add', {
    'url': url,
    'savePath': output,
    'options': options.toJson(),
    'startPaused': startPaused,
    'schedule': schedule?.toJson(),
    'allowDuplicate': allowDuplicate,
  });
  await ctx.client.close();
  if (!resp.ok) {
    stderr.writeln(ctx.theme.error('Error: ${resp.error}'));
    return 1;
  }
  final id = (resp.data as Map)['id'];
  final status = (resp.data as Map)['status'];
  if (ctx.jsonOutput) {
    stdout.writeln(resp.data);
  } else if (status == 'scheduled') {
    ctx.log('Scheduled $id. Use "pdm list" to check on it.');
  } else if (status == 'paused') {
    ctx.log('Added $id (paused). Run "pdm resume $id" to start it.');
  } else {
    ctx.log(
      'Added $id (running in background). Use "pdm watch $id" to follow progress.',
    );
  }
  return 0;
}
Future<int> _runBatch(
  CliContext ctx,
  String filePath,
  TaskOptions options,
  Schedule? schedule,
  bool allowDuplicate,
  bool startPaused,
) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    stderr.writeln(ctx.theme.error('File not found: $filePath'));
    return 1;
  }
  final urls = file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  if (urls.isEmpty) {
    stderr.writeln(ctx.theme.error('No URLs found in $filePath'));
    return 1;
  }
  await ctx.client.connect(allowSpawn: ctx.allowSpawn);
  var failures = 0;
  for (final url in urls) {
    final resp = await ctx.client.request('add', {
      'url': url,
      'savePath': null,
      'options': options.toJson(),
      'startPaused': startPaused,
      'schedule': schedule?.toJson(),
      'allowDuplicate': allowDuplicate,
    });
    if (!resp.ok) {
      failures++;
      stderr.writeln(ctx.theme.error('$url: ${resp.error}'));
    } else {
      final id = (resp.data as Map)['id'];
      ctx.log('Added $id  $url');
    }
  }
  await ctx.client.close();
  ctx.log('Queued ${urls.length - failures}/${urls.length} downloads.');
  return failures == 0 ? 0 : 1;
}

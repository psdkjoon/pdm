import 'dart:io';
import '../../config.dart';
import '../../daemon/daemon_server.dart';
import '../../service_install.dart';
import '../context.dart';
import '../parser.dart';
Future<int> runDaemonCmd(CliContext ctx, ParsedArgs args) async {
  if (args.positionals.isEmpty) {
    stderr.writeln('Usage: pdm daemon <start|stop|status|enable|disable> [flags]');
    return 1;
  }
  final action = args.positionals.first;
  switch (action) {
    case 'start':
      if (args.flag('foreground')) {
        final server = await runDaemon(
          maxConcurrentTasks: ctx.config.maxConcurrentTasks,
          address: ctx.client.address,
          downloadDir: expandHome(ctx.config.downloadDir),
          rules: ctx.config.rules,
          onCompleteAliases: ctx.config.onCompleteAliases,
          notifications: ctx.config.notifications,
          globalSpeedLimitBytesPerSec: ctx.config.globalSpeedLimitBytesPerSec,
        );
        ctx.log('pdm daemon listening (foreground)');
        await ProcessSignal.sigint.watch().first;
        await server.stop();
        return 0;
      }
      await ctx.client.connect(allowSpawn: true);
      final resp = await ctx.client.request('ping');
      await ctx.client.close();
      if (resp.ok) {
        ctx.log('pdm daemon is running');
        return 0;
      }
      stderr.writeln(ctx.theme.error('Failed to start daemon'));
      return 1;
    case 'stop':
      try {
        await ctx.client.connect(allowSpawn: false);
      } catch (_) {
        ctx.log('pdm daemon is not running');
        return 0;
      }
      await ctx.client.request('shutdown');
      await ctx.client.close();
      ctx.log('pdm daemon stopped');
      return 0;
    case 'status':
      try {
        await ctx.client.connect(allowSpawn: false);
      } catch (_) {
        ctx.log(ctx.theme.warn('pdm daemon is not running'));
        return 1;
      }
      final pingResp = await ctx.client.request('ping');
      await ctx.client.close();
      ctx.log(pingResp.ok ? ctx.theme.success('pdm daemon is running') : ctx.theme.error('unreachable'));
      return pingResp.ok ? 0 : 1;
    case 'enable':
      final result = await installDaemonService();
      ctx.log(result.success ? ctx.theme.success(result.message) : ctx.theme.error(result.message));
      return result.success ? 0 : 1;
    case 'disable':
      final result = await uninstallDaemonService();
      ctx.log(result.success ? ctx.theme.success(result.message) : ctx.theme.error(result.message));
      return result.success ? 0 : 1;
    default:
      stderr.writeln('Unknown daemon action "$action" (use start, stop, status, enable, or disable)');
      return 1;
  }
}

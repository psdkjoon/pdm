import 'dart:io';
import '../config.dart';
import '../daemon/daemon_client.dart';
import '../daemon/socket_address.dart';
import 'parser.dart';
import 'theme.dart';
class CliContext {
  final PdmConfig config;
  final CliTheme theme;
  final bool jsonOutput;
  final bool quiet;
  final bool verbose;
  final bool allowSpawn;
  final DaemonClient client;
  CliContext({
    required this.config,
    required this.theme,
    required this.jsonOutput,
    required this.quiet,
    required this.verbose,
    required this.allowSpawn,
    required this.client,
  });
  static Future<CliContext> build(ParsedArgs args) async {
    final config = loadConfig(path: args.str('config'));
    final colorEnabled =
        !args.flag('no-color') && config.color && stdout.hasTerminal;
    final themeName = args.str('theme') ?? config.theme;
    final theme = themeByName(themeName, colorEnabled: colorEnabled);
    final address = resolveSocketAddress(
      socketPathOverride: expandHome(
        args.str('socket-path') ?? config.socketPath,
      ),
      hostOverride: args.str('daemon-host') ?? config.daemonHost,
      portOverride: args.intVal('daemon-port') ?? config.daemonPort,
    );
    final allowSpawn = !args.flag('no-spawn');
    final client = DaemonClient(address);
    return CliContext(
      config: config,
      theme: theme,
      jsonOutput: args.flag('json'),
      quiet: args.flag('quiet'),
      verbose: args.flag('verbose'),
      allowSpawn: allowSpawn,
      client: client,
    );
  }
  void log(String message) {
    if (!quiet) stdout.writeln(message);
  }
}

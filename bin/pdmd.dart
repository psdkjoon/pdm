import 'dart:async';
import 'dart:io';
import 'package:pdm/src/config.dart';
import 'package:pdm/src/daemon/daemon_server.dart';
import 'package:pdm/src/daemon/socket_address.dart';
Future<void> main(List<String> argv) async {
  final config = loadConfig();
  final address = resolveSocketAddress(
    socketPathOverride: expandHome(config.socketPath),
    hostOverride: config.daemonHost,
    portOverride: config.daemonPort,
  );
  await runDaemon(
    maxConcurrentTasks: config.maxConcurrentTasks,
    address: address,
    downloadDir: expandHome(config.downloadDir),
    rules: config.rules,
    onCompleteAliases: config.onCompleteAliases,
    notifications: config.notifications,
    globalSpeedLimitBytesPerSec: config.globalSpeedLimitBytesPerSec,
  );
  if (!Platform.isWindows) {
    await ProcessSignal.sigterm.watch().first.catchError((_) => ProcessSignal.sigterm);
  } else {
    await Completer<void>().future;
  }
}

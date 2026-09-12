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
  final server = await runDaemon(
    maxConcurrentTasks: config.maxConcurrentTasks,
    address: address,
    downloadDir: expandHome(config.downloadDir),
    rules: config.rules,
    onCompleteAliases: config.onCompleteAliases,
    notifications: config.notifications,
    globalSpeedLimitBytesPerSec: config.globalSpeedLimitBytesPerSec,
  );
  final done = Completer<void>();
  Future<void> shutdown() async {
    if (done.isCompleted) return;
    await server.stop();
    done.complete();
  }

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().first.then((_) => shutdown());
    ProcessSignal.sigint.watch().first.then((_) => shutdown());
  } else {
    ProcessSignal.sigint.watch().first.then((_) => shutdown());
  }
  await done.future;
  exit(0);
}

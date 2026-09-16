import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'protocol.dart';
import 'socket_address.dart';

(String, List<String>) resolvePdmdCommand() {
  final exeName = Platform.isWindows ? 'pdmd.exe' : 'pdmd';
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final sibling = '$exeDir${Platform.pathSeparator}$exeName';
  if (File(sibling).existsSync()) {
    return (sibling, const []);
  }
  final envOverride = Platform.environment['PDMD_PATH'];
  if (envOverride != null && File(envOverride).existsSync()) {
    return (envOverride, const []);
  }
  final script = Platform.script.toFilePath();
  if (script.endsWith('pdm.dart')) {
    final daemonScript = script.replaceFirst(
      RegExp(r'pdm\.dart$'),
      'pdmd.dart',
    );
    if (File(daemonScript).existsSync()) {
      return (Platform.resolvedExecutable, [daemonScript]);
    }
  }
  throw DaemonUnavailableException(
    'Could not locate the pdmd binary next to "${Platform.resolvedExecutable}". '
    'Set PDMD_PATH to its location, or reinstall pdm.',
  );
}

class DaemonUnavailableException implements Exception {
  final String message;
  DaemonUnavailableException(this.message);
  @override
  String toString() => message;
}

class DaemonClient {
  final SocketAddress address;
  Socket? _socket;
  StreamSubscription<String>? _sub;
  DaemonClient(this.address);
  Future<bool> _tryConnect() async {
    try {
      _socket = address.useUnixSocket
          ? await Socket.connect(
              InternetAddress(
                address.unixPath!,
                type: InternetAddressType.unix,
              ),
              0,
              timeout: const Duration(seconds: 2),
            )
          : await Socket.connect(
              address.tcpHost,
              address.tcpPort,
              timeout: const Duration(seconds: 2),
            );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect({bool allowSpawn = true}) async {
    if (await _tryConnect()) return;
    if (!allowSpawn) {
      throw DaemonUnavailableException(
        'pdm daemon is not running (use "pdm daemon start" or drop --no-spawn)',
      );
    }
    await _spawnDaemon();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (await _tryConnect()) return;
    }
    throw DaemonUnavailableException('Failed to start pdm daemon');
  }

  Future<void> _spawnDaemon() async {
    final (executable, args) = resolvePdmdCommand();
    await Process.start(
      executable,
      args,
      mode: ProcessStartMode.detachedWithStdio,
    );
  }

  Future<DaemonResponse> request(
    String command, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (_socket == null) throw StateError('Not connected');
    final completer = Completer<DaemonResponse>();
    late StreamSubscription<String> sub;
    sub = _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (!completer.isCompleted) {
            completer.complete(DaemonResponse.decode(line));
            sub.cancel();
          }
        });
    _socket!.write(DaemonRequest(command, args).encode());
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw DaemonUnavailableException('Daemon request timed out'),
    );
  }

  Stream<DaemonEvent> watch(String id) {
    final controller = StreamController<DaemonEvent>();
    _socket!.write(DaemonRequest('watch', {'id': id}).encode());
    _sub = _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (DaemonEvent.isEvent(line)) {
              final event = DaemonEvent.decode(line);
              if (event.task['id'] == id) controller.add(event);
            }
          },
          onDone: controller.close,
        );
    controller.onCancel = () => _sub?.cancel();
    return controller.stream;
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _socket?.close();
  }
}

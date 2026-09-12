import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../download_manager.dart';
import '../models.dart';
import '../store.dart';
import 'protocol.dart';
import 'socket_address.dart';
class DaemonServer {
  final DownloadManager manager;
  final SocketAddress address;
  final List<Socket> _watchers = [];
  ServerSocket? _server;
  DaemonServer({DownloadManager? manager, SocketAddress? address})
    : manager = manager ?? DownloadManager(),
      address = address ?? resolveSocketAddress() {
    this.manager.events.listen(_broadcastEvent);
  }
  Future<void> start() async {
    if (address.useUnixSocket) {
      final path = address.unixPath!;
      final file = File(path);
      file.parent.createSync(recursive: true);
      if (file.existsSync()) file.deleteSync();
      _server = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
    } else {
      _server = await ServerSocket.bind(address.tcpHost, address.tcpPort);
    }
    _server!.listen(_handleConnection);
  }
  Future<void> stop() async {
    await _server?.close();
    manager.dispose();
  }
  void _broadcastEvent(TaskRecord record) {
    final line = DaemonEvent(record.toJson()).encode();
    for (final w in List.of(_watchers)) {
      try {
        w.write(line);
      } catch (_) {
        _watchers.remove(w);
      }
    }
  }
  void _handleConnection(Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _handleLine(socket, line),
          onDone: () => _watchers.remove(socket),
        );
  }
  Future<void> _handleLine(Socket socket, String line) async {
    if (line.trim().isEmpty) return;
    late DaemonRequest req;
    try {
      req = DaemonRequest.decode(line);
    } catch (e) {
      socket.write(DaemonResponse.err('Malformed request: $e').encode());
      return;
    }
    try {
      final response = await _dispatch(socket, req);
      if (response != null) socket.write(response.encode());
    } catch (e) {
      socket.write(DaemonResponse.err(e.toString()).encode());
    }
  }
  Future<DaemonResponse?> _dispatch(Socket socket, DaemonRequest req) async {
    switch (req.command) {
      case 'ping':
        return DaemonResponse.ok('pong');
      case 'add':
        final scheduleJson = req.args['schedule'] as Map?;
        final record = manager.add(
          req.args['url'] as String,
          savePath: req.args['savePath'] as String?,
          options: TaskOptions.fromJson(
            (req.args['options'] as Map).cast<String, dynamic>(),
          ),
          startPaused: req.args['startPaused'] as bool? ?? false,
          schedule: scheduleJson != null
              ? Schedule.fromJson(scheduleJson.cast<String, dynamic>())
              : null,
          allowDuplicate: req.args['allowDuplicate'] as bool? ?? false,
        );
        return DaemonResponse.ok(record.toJson());
      case 'list':
        return DaemonResponse.ok(manager.tasks.map((t) => t.toJson()).toList());
      case 'get':
        final record = manager.get(req.args['id'] as String);
        if (record == null) return DaemonResponse.err('Task not found');
        return DaemonResponse.ok(record.toJson());
      case 'start':
        await manager.start(req.args['id'] as String);
        return DaemonResponse.ok();
      case 'pause':
        await manager.pause(req.args['id'] as String);
        return DaemonResponse.ok();
      case 'cancel':
        await manager.cancel(req.args['id'] as String);
        return DaemonResponse.ok();
      case 'remove':
        await manager.remove(
          req.args['id'] as String,
          deleteFile: req.args['deleteFile'] as bool? ?? false,
        );
        return DaemonResponse.ok();
      case 'watch':
        _watchers.add(socket);
        final record = manager.get(req.args['id'] as String);
        if (record != null) {
          socket.write(DaemonEvent(record.toJson()).encode());
        }
        return null;
      case 'shutdown':
        Future.microtask(() async {
          await stop();
          exit(0);
        });
        return DaemonResponse.ok();
      default:
        return DaemonResponse.err('Unknown command "${req.command}"');
    }
  }
}
Future<DaemonServer> runDaemon({
  int maxConcurrentTasks = 3,
  TaskStore? store,
  SocketAddress? address,
  String? downloadDir,
  List<DownloadRule> rules = const [],
  Map<String, String> onCompleteAliases = const {},
  bool notifications = false,
  int? globalSpeedLimitBytesPerSec,
}) async {
  final manager = DownloadManager(
    store: store,
    maxConcurrentTasks: maxConcurrentTasks,
    downloadDir: downloadDir,
    rules: rules,
    onCompleteAliases: onCompleteAliases,
    notifications: notifications,
    globalSpeedLimitBytesPerSec: globalSpeedLimitBytesPerSec,
  );
  final server = DaemonServer(manager: manager, address: address);
  await server.start();
  return server;
}

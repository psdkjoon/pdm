import 'dart:io';

import '../config.dart' show defaultStateDir;

class SocketAddress {
  final bool useUnixSocket;
  final String? unixPath;
  final String tcpHost;
  final int tcpPort;
  SocketAddress.unix(this.unixPath)
    : useUnixSocket = true,
      tcpHost = '127.0.0.1',
      tcpPort = 0;
  SocketAddress.tcp(this.tcpHost, this.tcpPort)
    : useUnixSocket = false,
      unixPath = null;
}

SocketAddress resolveSocketAddress({
  String? socketPathOverride,
  String? hostOverride,
  int? portOverride,
}) {
  if (Platform.isWindows) {
    return SocketAddress.tcp(hostOverride ?? '127.0.0.1', portOverride ?? 7420);
  }
  return SocketAddress.unix(
    socketPathOverride ?? '${defaultStateDir()}/pdm.sock',
  );
}

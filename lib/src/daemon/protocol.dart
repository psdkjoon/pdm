import 'dart:convert';
class DaemonRequest {
  final String command;
  final Map<String, dynamic> args;
  DaemonRequest(this.command, [this.args = const {}]);
  String encode() => jsonEncode({'command': command, 'args': args}) + '\n';
  factory DaemonRequest.decode(String line) {
    final j = jsonDecode(line) as Map<String, dynamic>;
    return DaemonRequest(
      j['command'] as String,
      (j['args'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
class DaemonResponse {
  final bool ok;
  final dynamic data;
  final String? error;
  DaemonResponse.ok([this.data]) : ok = true, error = null;
  DaemonResponse.err(this.error) : ok = false, data = null;
  String encode() => jsonEncode({'ok': ok, 'data': data, 'error': error}) + '\n';
  factory DaemonResponse.decode(String line) {
    final j = jsonDecode(line) as Map<String, dynamic>;
    if (j['ok'] == true) return DaemonResponse.ok(j['data']);
    return DaemonResponse.err(j['error'] as String?);
  }
}
class DaemonEvent {
  final Map<String, dynamic> task;
  DaemonEvent(this.task);
  String encode() => jsonEncode({'event': 'task', 'task': task}) + '\n';
  static bool isEvent(String line) {
    try {
      final j = jsonDecode(line);
      return j is Map && j['event'] == 'task';
    } catch (_) {
      return false;
    }
  }
  factory DaemonEvent.decode(String line) {
    final j = jsonDecode(line) as Map<String, dynamic>;
    return DaemonEvent((j['task'] as Map).cast<String, dynamic>());
  }
}

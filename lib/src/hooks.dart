import 'dart:async';
import 'dart:io';
Map<String, String> builtinOnCompleteCommands() {
  if (Platform.isWindows) {
    return {
      'shutdown': 'shutdown /s /t 0',
      'restart': 'shutdown /r /t 0',
      'sleep': 'rundll32.exe powrprof.dll,SetSuspendState 0,1,0',
      'hibernate': 'shutdown /h',
      'lock': 'rundll32.exe user32.dll,LockWorkStation',
    };
  }
  if (Platform.isMacOS) {
    return {
      'shutdown': 'shutdown -h now',
      'restart': 'shutdown -r now',
      'sleep': 'pmset sleepnow',
      'hibernate': 'pmset sleepnow',
      'lock': 'pmset displaysleepnow',
    };
  }
  return {
    'shutdown': 'systemctl poweroff',
    'restart': 'systemctl reboot',
    'sleep': 'systemctl suspend',
    'hibernate': 'systemctl hibernate',
    'lock': 'loginctl lock-session',
  };
}
String resolveOnCompleteCommand(String spec, Map<String, String> aliases) {
  if (aliases.containsKey(spec)) return aliases[spec]!;
  final builtins = builtinOnCompleteCommands();
  if (builtins.containsKey(spec)) return builtins[spec]!;
  return spec;
}
String _fillTemplate(String command, Map<String, String> vars) {
  var result = command;
  for (final entry in vars.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}
Future<void> runOnComplete(
  String spec,
  Map<String, String> aliases, {
  required String taskId,
  required String url,
  required String savePath,
  required String status,
}) async {
  final resolved = resolveOnCompleteCommand(spec, aliases);
  final filled = _fillTemplate(resolved, {
    'id': taskId,
    'url': url,
    'path': savePath,
    'status': status,
  });
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', filled]);
    } else {
      await Process.run('/bin/sh', ['-c', filled]);
    }
  } catch (_) {}
}
Future<void> sendNotification(String title, String body) async {
  try {
    if (Platform.isWindows) {
      final user = Platform.environment['USERNAME'] ?? '*';
      unawaited(Process.run('msg', [user, '$title: $body']));
    } else if (Platform.isMacOS) {
      unawaited(
        Process.run('osascript', [
          '-e',
          'display notification "$body" with title "$title"',
        ]),
      );
    } else {
      unawaited(Process.run('notify-send', [title, body]));
    }
  } catch (_) {}
}

import 'dart:io';
Future<int?> availableDiskSpace(String dirPath) async {
  try {
    var dir = dirPath;
    while (!Directory(dir).existsSync()) {
      final parent = Directory(dir).parent.path;
      if (parent == dir) break;
      dir = parent;
    }
    if (Platform.isWindows) {
      final drive = dir.length >= 2 && dir[1] == ':' ? dir.substring(0, 1) : 'C';
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-PSDrive $drive).Free',
      ]);
      if (result.exitCode != 0) return null;
      return int.tryParse(result.stdout.toString().trim());
    }
    final result = await Process.run('df', ['-Pk', dir]);
    if (result.exitCode != 0) return null;
    final lines = result.stdout.toString().trim().split('\n');
    if (lines.length < 2) return null;
    final fields = lines.last.trim().split(RegExp(r'\s+'));
    if (fields.length < 4) return null;
    final availableKb = int.tryParse(fields[3]);
    if (availableKb == null) return null;
    return availableKb * 1024;
  } catch (_) {
    return null;
  }
}

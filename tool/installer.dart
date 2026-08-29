import 'dart:convert';
import 'dart:io';

import 'generated_payload.dart';

void main(List<String> args) {
  final payload = base64.decode(pdmPayloadChunks.join());

  if (payload.isEmpty) {
    stderr.writeln(
      'This installer has no embedded payload. Did you run the raw stub '
      'instead of a release asset from GitHub?',
    );
    exit(1);
  }

  final installDir = _installDir(args);
  final targetPath = Platform.isWindows
      ? '${installDir.path}${Platform.pathSeparator}pdm.exe'
      : '${installDir.path}${Platform.pathSeparator}pdm';

  installDir.createSync(recursive: true);
  File(targetPath).writeAsBytesSync(payload);

  if (!Platform.isWindows) {
    final chmod = Process.runSync('chmod', ['+x', targetPath]);
    if (chmod.exitCode != 0) {
      stderr.writeln('Warning: chmod +x failed: ${chmod.stderr}');
    }
  }

  stdout.writeln('Installed pdm -> $targetPath');
  _ensureOnPath(installDir.path);
}

Directory _installDir(List<String> args) {
  final dirFlagIndex = args.indexOf('--dir');
  if (dirFlagIndex != -1 && dirFlagIndex + 1 < args.length) {
    return Directory(args[dirFlagIndex + 1]);
  }

  if (Platform.isWindows) {
    final localAppData =
        Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return Directory('$localAppData\\Programs\\pdm');
  }

  final home = Platform.environment['HOME'] ?? '.';
  return Directory('$home/.local/bin');
}

void _ensureOnPath(String dirPath) {
  if (Platform.isWindows) {
    final script =
        '''
\$current = [Environment]::GetEnvironmentVariable("Path", "User")
if (\$current -notlike "*$dirPath*") {
  [Environment]::SetEnvironmentVariable("Path", "\$current;$dirPath", "User")
  Write-Host "Added $dirPath to your user PATH. Restart your terminal to use pdm."
} else {
  Write-Host "$dirPath is already on PATH."
}
''';
    final result = Process.runSync('powershell', [
      '-NoProfile',
      '-Command',
      script,
    ]);
    stdout.write(result.stdout);
    if (result.exitCode != 0) stderr.write(result.stderr);
    return;
  }

  final pathEnv = Platform.environment['PATH'] ?? '';
  if (pathEnv.split(':').contains(dirPath)) {
    stdout.writeln('$dirPath is already on PATH.');
  } else {
    stdout.writeln('NOTE: $dirPath is not on your PATH.');
    stdout.writeln('Add this to your shell profile (~/.bashrc, ~/.zshrc, etc):');
    stdout.writeln('  export PATH="$dirPath:\$PATH"');
  }
}

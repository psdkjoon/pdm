import 'dart:convert';
import 'dart:io';

const List<String> _pdmPayloadChunks = [];
const List<String> _pdmdPayloadChunks = [];

void main(List<String> args) {
  if (args.isNotEmpty && args.first == 'generate') {
    _runGenerate(args.skip(1).toList());
    return;
  }
  _runInstall(args);
}

const _chunkSize = 76;

void _runGenerate(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/installer.dart generate <pdm_binary> <pdmd_binary> <output_dart_file>',
    );
    exit(1);
  }

  final pdmPayload = File(args[0]).readAsBytesSync();
  final pdmdPayload = File(args[1]).readAsBytesSync();

  var source = File(Platform.script.toFilePath()).readAsStringSync();
  source = source.replaceFirst(
    RegExp(r'const List<String> _pdmPayloadChunks = \[[\s\S]*?\];'),
    'const List<String> _pdmPayloadChunks = [\n${_chunkify(pdmPayload).join('\n')}\n];',
  );
  source = source.replaceFirst(
    RegExp(r'const List<String> _pdmdPayloadChunks = \[[\s\S]*?\];'),
    'const List<String> _pdmdPayloadChunks = [\n${_chunkify(pdmdPayload).join('\n')}\n];',
  );

  File(args[2]).writeAsStringSync(source);
  stdout.writeln(
    'Generated ${args[2]} (pdm ${pdmPayload.length}B, pdmd ${pdmdPayload.length}B)',
  );
}

List<String> _chunkify(List<int> payload) {
  final encoded = base64.encode(payload);
  final chunks = <String>[];
  for (var i = 0; i < encoded.length; i += _chunkSize) {
    final end = (i + _chunkSize < encoded.length) ? i + _chunkSize : encoded.length;
    chunks.add("  '${encoded.substring(i, end)}',");
  }
  return chunks;
}

void _runInstall(List<String> args) {
  final pdmPayload = base64.decode(_pdmPayloadChunks.join());
  final pdmdPayload = base64.decode(_pdmdPayloadChunks.join());

  if (pdmPayload.isEmpty || pdmdPayload.isEmpty) {
    stderr.writeln(
      'This installer has no embedded payload. Did you run the raw stub '
      'instead of a release asset from GitHub?',
    );
    exit(1);
  }

  final installDir = _installDir(args);
  final pdmPath = Platform.isWindows
      ? '${installDir.path}${Platform.pathSeparator}pdm.exe'
      : '${installDir.path}${Platform.pathSeparator}pdm';
  final pdmdPath = Platform.isWindows
      ? '${installDir.path}${Platform.pathSeparator}pdmd.exe'
      : '${installDir.path}${Platform.pathSeparator}pdmd';

  installDir.createSync(recursive: true);
  File(pdmPath).writeAsBytesSync(pdmPayload);
  File(pdmdPath).writeAsBytesSync(pdmdPayload);

  if (!Platform.isWindows) {
    for (final path in [pdmPath, pdmdPath]) {
      final chmod = Process.runSync('chmod', ['+x', path]);
      if (chmod.exitCode != 0) {
        stderr.writeln('Warning: chmod +x failed for $path: ${chmod.stderr}');
      }
    }
  }

  stdout.writeln('Installed pdm -> $pdmPath');
  stdout.writeln('Installed pdmd -> $pdmdPath');
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

import 'dart:convert';
import 'dart:io';

import 'package:pdm/pdm.dart' show sha256Hex;

const List<String> _pdmPayloadChunks = [];
const List<String> _pdmdPayloadChunks = [];
const String _pdmSha256 = '';
const String _pdmdSha256 = '';

void main(List<String> args) {
  if (args.isNotEmpty && args.first == 'generate') {
    _runGenerate(args.skip(1).toList());
    return;
  }
  if (args.isNotEmpty && args.first == 'uninstall') {
    _runUninstall(args.skip(1).toList());
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

  final pdmBytes = File(args[0]).readAsBytesSync();
  final pdmdBytes = File(args[1]).readAsBytesSync();

  var source = File(Platform.script.toFilePath()).readAsStringSync();
  source = source.replaceFirst(
    RegExp(r'const List<String> _pdmPayloadChunks = \[[\s\S]*?\];'),
    'const List<String> _pdmPayloadChunks = [\n${_chunkify(pdmBytes).join('\n')}\n];',
  );
  source = source.replaceFirst(
    RegExp(r'const List<String> _pdmdPayloadChunks = \[[\s\S]*?\];'),
    'const List<String> _pdmdPayloadChunks = [\n${_chunkify(pdmdBytes).join('\n')}\n];',
  );
  source = source.replaceFirst(
    RegExp(r"const String _pdmSha256 = '[^']*';"),
    "const String _pdmSha256 = '${sha256Hex(pdmBytes)}';",
  );
  source = source.replaceFirst(
    RegExp(r"const String _pdmdSha256 = '[^']*';"),
    "const String _pdmdSha256 = '${sha256Hex(pdmdBytes)}';",
  );

  File(args[2]).writeAsStringSync(source);
  stdout.writeln(
    'Generated ${args[2]} (pdm ${pdmBytes.length}B, pdmd ${pdmdBytes.length}B)',
  );
}

List<String> _chunkify(List<int> payload) {
  final encoded = base64.encode(payload);
  final chunks = <String>[];
  for (var i = 0; i < encoded.length; i += _chunkSize) {
    final end =
        (i + _chunkSize < encoded.length) ? i + _chunkSize : encoded.length;
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

  if (_pdmSha256.isNotEmpty && sha256Hex(pdmPayload) != _pdmSha256) {
    stderr.writeln('Checksum mismatch for the embedded pdm binary. Aborting.');
    exit(1);
  }
  if (_pdmdSha256.isNotEmpty && sha256Hex(pdmdPayload) != _pdmdSha256) {
    stderr.writeln('Checksum mismatch for the embedded pdmd binary. Aborting.');
    exit(1);
  }

  final userInstall = args.contains('--user');
  final installDir = _installDir(args, userInstall: userInstall);
  final pdmPath = _binPath(installDir, 'pdm');
  final pdmdPath = _binPath(installDir, 'pdmd');

  try {
    installDir.createSync(recursive: true);
    File(pdmPath).writeAsBytesSync(pdmPayload);
    File(pdmdPath).writeAsBytesSync(pdmdPayload);
  } on FileSystemException {
    if (!Platform.isWindows && !userInstall) {
      stderr.writeln(
        'Could not write to ${installDir.path} (permission denied).',
      );
      stderr.writeln('Run this to install system-wide:');
      stderr.writeln('  sudo ${_selfInvocation()}');
      stderr.writeln('Or install it for your user only:');
      stderr.writeln('  ${_selfInvocation()} --user');
      exit(1);
    }
    rethrow;
  }

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
  _ensureOnPath(installDir.path, userInstall: userInstall);
  stdout.writeln();
  stdout.writeln(
    'Run "pdm completion bash" (or zsh) to set up tab completion.',
  );
  stdout.writeln(
    'Run "pdm daemon enable" to start the daemon automatically at login.',
  );
}

void _runUninstall(List<String> args) {
  final userInstall = args.contains('--user');
  final installDir = _installDir(args, userInstall: userInstall);
  final pdmPath = _binPath(installDir, 'pdm');
  final pdmdPath = _binPath(installDir, 'pdmd');

  var removedAny = false;
  try {
    for (final path in [pdmPath, pdmdPath]) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        stdout.writeln('Removed $path');
        removedAny = true;
      }
    }
  } on FileSystemException {
    if (!Platform.isWindows && !userInstall) {
      stderr.writeln(
        'Could not remove files from ${installDir.path} (permission denied).',
      );
      stderr.writeln('Run this to uninstall system-wide:');
      stderr.writeln('  sudo ${_selfInvocation()} uninstall');
      stderr.writeln('Or uninstall your user install:');
      stderr.writeln('  ${_selfInvocation()} uninstall --user');
      exit(1);
    }
    rethrow;
  }

  if (!Platform.isWindows) {
    Process.runSync('systemctl', [
      '--user',
      'disable',
      '--now',
      'pdmd.service',
    ]);
    final unit = File('${_homeDir()}/.config/systemd/user/pdmd.service');
    if (unit.existsSync()) {
      unit.deleteSync();
      Process.runSync('systemctl', ['--user', 'daemon-reload']);
      stdout.writeln('Removed the pdmd systemd --user service.');
    }
    for (final path in [
      '/usr/share/bash-completion/completions/pdm',
      '/usr/share/zsh/site-functions/_pdm',
      '${_homeDir()}/.local/share/bash-completion/completions/pdm',
      '${_homeDir()}/.local/share/zsh/site-functions/_pdm',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
          stdout.writeln('Removed $path');
        } catch (_) {
          stderr.writeln(
            'Could not remove $path (permission denied); run with sudo to clean it up.',
          );
        }
      }
    }
  } else {
    Process.runSync('schtasks', ['/delete', '/tn', 'pdm daemon', '/f']);
  }

  if (!removedAny) {
    stdout.writeln('pdm was not found in ${installDir.path}.');
  } else {
    stdout.writeln('pdm has been uninstalled.');
  }
}

String _selfInvocation() => Platform.resolvedExecutable;

String _binPath(Directory dir, String name) {
  final exe = Platform.isWindows ? '$name.exe' : name;
  return '${dir.path}${Platform.pathSeparator}$exe';
}

Directory _installDir(List<String> args, {required bool userInstall}) {
  final dirFlagIndex = args.indexOf('--dir');
  if (dirFlagIndex != -1 && dirFlagIndex + 1 < args.length) {
    return Directory(args[dirFlagIndex + 1]);
  }

  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return Directory('$localAppData\\Programs\\pdm');
  }

  if (userInstall) {
    return Directory('${_homeDir()}/.local/bin');
  }
  return Directory('/usr/bin');
}

String _homeDir() => Platform.environment['HOME'] ?? '.';

void _ensureOnPath(String dirPath, {required bool userInstall}) {
  if (Platform.isWindows) {
    final script = '''
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

  if (!userInstall) return;

  final pathEnv = Platform.environment['PATH'] ?? '';
  if (pathEnv.split(':').contains(dirPath)) {
    stdout.writeln('$dirPath is already on PATH.');
  } else {
    stdout.writeln('NOTE: $dirPath is not on your PATH.');
    stdout.writeln(
      'Add this to your shell profile (~/.bashrc, ~/.zshrc, etc):',
    );
    stdout.writeln('  export PATH="$dirPath:\$PATH"');
  }
}

import 'dart:io';

import '../../config.dart' show homeDir;
import '../context.dart';
import '../flags.dart';
import '../parser.dart';

const _commands = [
  'add',
  'list',
  'ls',
  'pause',
  'resume',
  'start',
  'cancel',
  'remove',
  'rm',
  'watch',
  'daemon',
  'config',
  'history',
  'completion',
  'version',
  'help',
];
Future<int> runCompletion(CliContext ctx, ParsedArgs args) async {
  final shell = args.positionals.isNotEmpty ? args.positionals.first : null;
  if (shell == null || (shell != 'bash' && shell != 'zsh')) {
    stderr.writeln('Usage: pdm completion <bash|zsh> [--print] [--user]');
    return 1;
  }
  final script = shell == 'bash' ? _bashScript() : _zshScript();
  if (args.flag('print') || Platform.isWindows) {
    stdout.writeln(script);
    if (Platform.isWindows && !args.flag('print')) {
      ctx.log(
        'Automatic install is only supported on Linux/macOS; pipe this into your shell config, e.g.:',
      );
      ctx.log('  pdm completion $shell >> ~/.bashrc');
    }
    return 0;
  }
  final forceUser = args.flag('user');
  final target = _targetPath(shell, forceUser: forceUser);
  try {
    final file = File(target);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(script);
    ctx.log(ctx.theme.success('Installed $shell completions to $target'));
    if (shell == 'bash' && !forceUser) {
      ctx.log('Restart your shell, or run: source $target');
    } else if (shell == 'zsh' && !forceUser) {
      ctx.log('Restart your shell, or run: autoload -U compinit && compinit');
    }
    return 0;
  } on FileSystemException {
    final systemTarget = _targetPath(shell, forceUser: false);
    stderr.writeln(
      ctx.theme.error('Could not write to $systemTarget (permission denied).'),
    );
    stderr.writeln('Run this to install system-wide:');
    stderr.writeln('  sudo pdm completion $shell');
    stderr.writeln('Or install it for your user only:');
    stderr.writeln('  pdm completion $shell --user');
    return 1;
  }
}

String _targetPath(String shell, {required bool forceUser}) {
  if (forceUser) {
    final base = homeDir();
    return shell == 'bash'
        ? '$base/.local/share/bash-completion/completions/pdm'
        : '$base/.local/share/zsh/site-functions/_pdm';
  }
  return shell == 'bash'
      ? '/usr/share/bash-completion/completions/pdm'
      : '/usr/share/zsh/site-functions/_pdm';
}

String _allLongFlags() {
  final set = <String>{};
  for (final f in globalFlags) {
    set.add('--${f.long}');
  }
  for (final flags in commandFlags.values) {
    for (final f in flags) {
      set.add('--${f.long}');
    }
  }
  return set.join(' ');
}

String _bashScript() {
  final commands = _commands.join(' ');
  final flags = _allLongFlags();
  return '_pdm_completions() {\n'
      '  local cur\n'
      '  cur="\${COMP_WORDS[COMP_CWORD]}"\n'
      '  if [ "\$COMP_CWORD" -eq 1 ]; then\n'
      '    COMPREPLY=( \$(compgen -W "$commands" -- "\$cur") )\n'
      '    return\n'
      '  fi\n'
      '  COMPREPLY=( \$(compgen -W "$flags" -- "\$cur") )\n'
      '}\n'
      'complete -F _pdm_completions pdm\n';
}

String _zshScript() {
  final commands = _commands.join(' ');
  final flags = _allLongFlags();
  return '#compdef pdm\n'
      '_pdm() {\n'
      '  local -a commands flags\n'
      '  commands=($commands)\n'
      '  flags=($flags)\n'
      '  if (( CURRENT == 2 )); then\n'
      '    _describe "command" commands\n'
      '  else\n'
      '    _describe "flag" flags\n'
      '  fi\n'
      '}\n'
      '_pdm\n';
}

import 'dart:io';
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
  switch (shell) {
    case 'bash':
      stdout.writeln(_bashScript());
      return 0;
    case 'zsh':
      stdout.writeln(_zshScript());
      return 0;
    default:
      stderr.writeln('Usage: pdm completion <bash|zsh>');
      return 1;
  }
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

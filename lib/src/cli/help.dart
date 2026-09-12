import 'flags.dart';
String _flagLine(FlagDef f) {
  final left = '  -${f.short}, --${f.long}';
  return '${left.padRight(28)}${f.help}';
}
String renderGlobalHelp() {
  final buf = StringBuffer();
  buf.writeln('pdm — psdk download manager');
  buf.writeln();
  buf.writeln('Usage: pdm <command> [flags]');
  buf.writeln();
  buf.writeln('Commands:');
  buf.writeln('  add <url>        Add and start a download');
  buf.writeln('  list             List all tasks');
  buf.writeln('  pause <id>       Pause a task');
  buf.writeln('  resume <id>      Resume a paused/queued task');
  buf.writeln('  cancel <id>      Cancel a task');
  buf.writeln('  remove <id>      Remove a task');
  buf.writeln('  watch <id>       Attach a live progress view to a task');
  buf.writeln('  daemon <action>  Manage the background daemon (start, stop, status, enable, disable)');
  buf.writeln('  config <action>  Manage the config file (dump)');
  buf.writeln('  history          Show completed/failed download history');
  buf.writeln('  completion       Print a shell completion script (bash, zsh)');
  buf.writeln('  version          Print the pdm version');
  buf.writeln('  help             Show this help, or "pdm help <command>"');
  buf.writeln();
  buf.writeln('Global flags:');
  for (final f in globalFlags) {
    buf.writeln(_flagLine(f));
  }
  buf.writeln();
  buf.writeln('Run "pdm help <command>" for flags specific to a command.');
  return buf.toString();
}
String renderCommandHelp(String command) {
  final flags = commandFlags[command];
  if (flags == null) {
    return 'Unknown command "$command". Run "pdm help" for a list of commands.';
  }
  final buf = StringBuffer();
  buf.writeln('pdm $command — flags');
  buf.writeln();
  for (final f in flags) {
    buf.writeln(_flagLine(f));
  }
  buf.writeln();
  buf.writeln('Global flags (also available):');
  for (final f in globalFlags) {
    buf.writeln(_flagLine(f));
  }
  return buf.toString();
}

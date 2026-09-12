import 'flags.dart';

class CommandInfo {
  final String usage;
  final String summary;
  final List<String> aliases;
  const CommandInfo(this.usage, this.summary, {this.aliases = const []});
}

const Map<String, CommandInfo> commandInfo = {
  'add': CommandInfo('pdm add <url> [flags]', 'Add and start a download'),
  'list': CommandInfo('pdm list [flags]', 'List all tasks', aliases: ['ls']),
  'pause': CommandInfo('pdm pause <id> [flags]', 'Pause a task'),
  'resume': CommandInfo(
    'pdm resume <id> [flags]',
    'Resume a paused/queued task',
    aliases: ['start'],
  ),
  'cancel': CommandInfo('pdm cancel <id> [flags]', 'Cancel a task'),
  'remove': CommandInfo(
    'pdm remove <id> [flags]',
    'Remove a task',
    aliases: ['rm'],
  ),
  'watch': CommandInfo(
    'pdm watch <id> [flags]',
    'Attach a live progress view to a task',
  ),
  'daemon': CommandInfo(
    'pdm daemon <start|stop|status|enable|disable> [flags]',
    'Manage the background daemon',
  ),
  'config': CommandInfo('pdm config dump [flags]', 'Manage the config file'),
  'history': CommandInfo(
    'pdm history [flags]',
    'Show completed/failed download history',
  ),
  'completion': CommandInfo(
    'pdm completion <bash|zsh>',
    'Install or print a shell completion script',
  ),
};

const List<String> _topLevelOnlyCommands = ['version', 'help'];

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
  for (final entry in commandInfo.entries) {
    final aliasSuffix = entry.value.aliases.isEmpty
        ? ''
        : ' (${entry.value.aliases.join(', ')})';
    final left = '  ${entry.key}$aliasSuffix';
    buf.writeln('${left.padRight(24)}${entry.value.summary}');
  }
  buf.writeln('  version                 Print the pdm version');
  buf.writeln(
    '  help [<command>]        Show this help, or help for one command',
  );
  buf.writeln();
  buf.writeln('Global flags:');
  for (final f in globalFlags) {
    buf.writeln(_flagLine(f));
  }
  buf.writeln();
  buf.writeln(
    'Run "pdm help <command>" or "pdm <command> --help" for command-specific flags.',
  );
  return buf.toString();
}

String renderCommandHelp(String command) {
  final resolved = _resolveAlias(command);
  final flags = commandFlags[resolved];
  final info = commandInfo[resolved];
  if (flags == null || info == null) {
    if (_topLevelOnlyCommands.contains(resolved)) {
      return 'pdm $resolved takes no flags of its own.\n\n'
          'Run "pdm help" for a list of commands.';
    }
    return _unknownCommandMessage(command);
  }
  final buf = StringBuffer();
  buf.writeln(info.usage);
  buf.writeln();
  buf.writeln(info.summary);
  if (info.aliases.isNotEmpty) {
    buf.writeln('Aliases: ${info.aliases.join(', ')}');
  }
  buf.writeln();
  if (flags.isNotEmpty) {
    buf.writeln('Flags:');
    for (final f in flags) {
      buf.writeln(_flagLine(f));
    }
    buf.writeln();
  }
  buf.writeln('Global flags (also available):');
  for (final f in globalFlags) {
    buf.writeln(_flagLine(f));
  }
  return buf.toString();
}

String _resolveAlias(String command) {
  if (commandFlags.containsKey(command)) return command;
  for (final entry in commandInfo.entries) {
    if (entry.value.aliases.contains(command)) return entry.key;
  }
  return command;
}

String _unknownCommandMessage(String command) {
  final known = [...commandFlags.keys, ..._topLevelOnlyCommands];
  final suggestion = _closestMatch(command, known);
  final buf = StringBuffer('Unknown command "$command".');
  if (suggestion != null) {
    buf.write(' Did you mean "$suggestion"?');
  }
  buf.write(' Run "pdm help" for a list of commands.');
  return buf.toString();
}

String? _closestMatch(String input, List<String> candidates) {
  String? best;
  var bestDistance = 3;
  for (final candidate in candidates) {
    final distance = _levenshtein(input, candidate);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

int _levenshtein(String a, String b) {
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) dp[i][0] = i;
  for (var j = 0; j <= b.length; j++) dp[0][j] = j;
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[a.length][b.length];
}

import 'dart:io';
import 'package:pdm/src/cli/commands/add.dart';
import 'package:pdm/src/cli/commands/completion.dart';
import 'package:pdm/src/cli/commands/config_cmd.dart';
import 'package:pdm/src/cli/commands/daemon_cmd.dart';
import 'package:pdm/src/cli/commands/history.dart';
import 'package:pdm/src/cli/commands/list.dart';
import 'package:pdm/src/cli/commands/task_action.dart';
import 'package:pdm/src/cli/commands/watch.dart';
import 'package:pdm/src/cli/context.dart';
import 'package:pdm/src/cli/flags.dart';
import 'package:pdm/src/cli/help.dart';
import 'package:pdm/src/cli/parser.dart';
import 'package:pdm/src/version.dart';
Future<void> main(List<String> argv) async {
  if (argv.isEmpty) {
    stdout.writeln(renderGlobalHelp());
    exit(0);
  }
  final command = argv.first;
  final rest = argv.skip(1).toList();
  if (command == 'help') {
    if (rest.isEmpty) {
      stdout.writeln(renderGlobalHelp());
    } else {
      stdout.writeln(renderCommandHelp(rest.first));
    }
    exit(0);
  }
  if (command == 'version') {
    stdout.writeln(pdmVersion());
    exit(0);
  }
  final extraFlags = commandFlags[command] ?? const [];
  ParsedArgs args;
  try {
    args = parseArgs(rest, extraFlags, globalFlags);
  } on FlagParseException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
  if (args.flag('help')) {
    stdout.writeln(renderCommandHelp(command));
    exit(0);
  }
  final ctx = await CliContext.build(args);
  int exitCode;
  try {
    switch (command) {
      case 'add':
        exitCode = await runAdd(ctx, args);
        break;
      case 'list':
      case 'ls':
        exitCode = await runList(ctx, args);
        break;
      case 'pause':
        exitCode = await runTaskAction(ctx, args, 'pause');
        break;
      case 'resume':
      case 'start':
        exitCode = await runTaskAction(ctx, args, 'resume');
        break;
      case 'cancel':
        exitCode = await runTaskAction(ctx, args, 'cancel');
        break;
      case 'remove':
      case 'rm':
        exitCode =
            await runTaskAction(ctx, args, 'remove', supportsDeleteFile: true);
        break;
      case 'watch':
        exitCode = await runWatch(ctx, args);
        break;
      case 'daemon':
        exitCode = await runDaemonCmd(ctx, args);
        break;
      case 'config':
        exitCode = await runConfigCmd(ctx, args);
        break;
      case 'history':
        exitCode = await runHistory(ctx, args);
        break;
      case 'completion':
        exitCode = await runCompletion(ctx, args);
        break;
      default:
        stderr.writeln('Unknown command "$command". Run "pdm help" for usage.');
        exitCode = 1;
    }
  } catch (e) {
    stderr.writeln(ctx.theme.error('Error: $e'));
    exitCode = 1;
  }
  exit(exitCode);
}

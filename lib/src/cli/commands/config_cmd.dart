import 'dart:io';

import 'package:pdata/pdata.dart';

import '../../config.dart';
import '../context.dart';
import '../parser.dart';

Future<int> runConfigCmd(CliContext ctx, ParsedArgs args) async {
  if (args.positionals.isEmpty || args.positionals.first != 'dump') {
    stderr.writeln(
      'Usage: pdm config dump [--format yaml|toml|json] [--output path] [--force]',
    );
    return 1;
  }
  final formatName = args.str('format') ?? 'yaml';
  PdataFormat format;
  try {
    format = formatFromName(formatName);
  } catch (e) {
    stderr.writeln(ctx.theme.error(e.toString()));
    return 1;
  }
  final output = args.str('output');
  if (output != null) {
    try {
      writeDefaultConfig(output, format: format, force: args.flag('force'));
      ctx.log(ctx.theme.success('Wrote default config to $output'));
      return 0;
    } catch (e) {
      stderr.writeln(ctx.theme.error(e.toString()));
      return 1;
    }
  }
  stdout.writeln(dumpDefaultConfig(format: format));
  return 0;
}

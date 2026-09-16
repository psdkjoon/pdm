import 'flags.dart';
import '../util.dart' show closestMatch, parseDurationSpec;
export '../util.dart' show parseByteSize, parseDurationSpec;

class ParsedArgs {
  final List<String> positionals;
  final Map<String, dynamic> values;
  ParsedArgs(this.positionals, this.values);
  String? str(String long) => values[long] as String?;
  bool flag(String long) => values[long] as bool? ?? false;
  List<String> multi(String long) =>
      (values[long] as List?)?.cast<String>() ?? const [];
  int? intVal(String long) {
    final v = values[long];
    if (v == null) return null;
    return int.tryParse(v as String);
  }
}

class FlagParseException implements Exception {
  final String message;
  FlagParseException(this.message);
  @override
  String toString() => message;
}

ParsedArgs parseArgs(
  List<String> args,
  List<FlagDef> extraFlags,
  List<FlagDef> globals,
) {
  final all = [...globals, ...extraFlags];
  final byLong = {for (final f in all) f.long: f};
  final byShort = {for (final f in all) f.short: f};
  final positionals = <String>[];
  final values = <String, dynamic>{};
  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    FlagDef? def;
    String? inlineValue;
    if (arg.startsWith('--')) {
      final eq = arg.indexOf('=');
      final name = eq == -1 ? arg.substring(2) : arg.substring(2, eq);
      inlineValue = eq == -1 ? null : arg.substring(eq + 1);
      def = byLong[name];
      if (def == null) {
        final suggestion = closestMatch(name, byLong.keys);
        throw FlagParseException(
          suggestion == null
              ? 'Unknown flag --$name'
              : 'Unknown flag --$name. Did you mean --$suggestion?',
        );
      }
    } else if (arg.startsWith('-') && arg.length > 1) {
      final name = arg.substring(1);
      def = byShort[name];
      if (def == null) throw FlagParseException('Unknown flag -$name');
    } else {
      positionals.add(arg);
      i++;
      continue;
    }
    switch (def.kind) {
      case FlagKind.flag:
        values[def.long] = true;
        i++;
        break;
      case FlagKind.string:
        final v = inlineValue ?? _nextValue(args, i, def.long);
        values[def.long] = v;
        i += inlineValue != null ? 1 : 2;
        break;
      case FlagKind.int:
        final v = inlineValue ?? _nextValue(args, i, def.long);
        values[def.long] = v;
        i += inlineValue != null ? 1 : 2;
        break;
      case FlagKind.multiString:
        final v = inlineValue ?? _nextValue(args, i, def.long);
        (values[def.long] ??= <String>[]).add(v);
        i += inlineValue != null ? 1 : 2;
        break;
    }
  }
  return ParsedArgs(positionals, values);
}

String _nextValue(List<String> args, int i, String flagName) {
  if (i + 1 >= args.length) {
    throw FlagParseException('Flag --$flagName expects a value');
  }
  return args[i + 1];
}

(String, String)? parseChecksumSpec(String? raw) {
  if (raw == null) return null;
  final idx = raw.indexOf(':');
  if (idx == -1)
    throw FlagParseException('--checksum expects "algo:hex", e.g. sha256:abcd');
  return (raw.substring(0, idx), raw.substring(idx + 1));
}

MapEntry<String, String> parseHeaderSpec(String raw) {
  final idx = raw.indexOf(':');
  if (idx == -1) throw FlagParseException('--header expects "Key: Value"');
  return MapEntry(raw.substring(0, idx).trim(), raw.substring(idx + 1).trim());
}

DateTime parseScheduleAt(String raw, DateTime now) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('+')) {
    final duration = parseDurationSpec(trimmed.substring(1));
    if (duration == null) {
      throw FlagParseException(
        '--at expects "+<duration>" (e.g. +30m, +2h) or a date/time, got "$raw"',
      );
    }
    return now.add(duration);
  }
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;
  final timeOnly = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
  if (timeOnly != null) {
    final hour = int.parse(timeOnly.group(1)!);
    final minute = int.parse(timeOnly.group(2)!);
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
  throw FlagParseException(
    '--at expects an ISO date/time, "HH:mm", or "+<duration>", got "$raw"',
  );
}

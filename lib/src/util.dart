int? parseByteSize(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([KMGkmg]?)$').firstMatch(raw.trim());
  if (match == null) return int.tryParse(raw);
  final value = double.parse(match.group(1)!);
  final unit = match.group(2)!.toUpperCase();
  final multiplier = switch (unit) {
    'K' => 1024,
    'M' => 1024 * 1024,
    'G' => 1024 * 1024 * 1024,
    _ => 1,
  };
  return (value * multiplier).round();
}
Duration? parseDurationSpec(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(ms|s|m|h|d)$',
  ).firstMatch(raw.trim().toLowerCase());
  if (match == null) return null;
  final value = double.parse(match.group(1)!);
  final unit = match.group(2)!;
  final msPerUnit = switch (unit) {
    'ms' => 1,
    's' => 1000,
    'm' => 60 * 1000,
    'h' => 60 * 60 * 1000,
    'd' => 24 * 60 * 60 * 1000,
    _ => 1000,
  };
  return Duration(milliseconds: (value * msPerUnit).round());
}

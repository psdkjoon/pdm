int? parseByteSize(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([KMGkmg]?)$')
      .firstMatch(raw.trim());
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

int levenshteinDistance(String a, String b) {
  final distances = List.generate(
    a.length + 1,
    (_) => List.filled(b.length + 1, 0),
  );
  for (var i = 0; i <= a.length; i++) {
    distances[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    distances[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1;
      distances[i][j] = [
        distances[i - 1][j] + 1,
        distances[i][j - 1] + 1,
        distances[i - 1][j - 1] + substitutionCost,
      ].reduce((x, y) => x < y ? x : y);
    }
  }
  return distances[a.length][b.length];
}

String? closestMatch(
  String input,
  Iterable<String> candidates, {
  int maxDistance = 2,
}) {
  String? best;
  var bestDistance = maxDistance + 1;
  for (final candidate in candidates) {
    final distance = levenshteinDistance(input, candidate);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

Duration? parseDurationSpec(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s*(ms|s|m|h|d)$')
      .firstMatch(raw.trim().toLowerCase());
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

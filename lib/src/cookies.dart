import 'dart:io';
String? parseInlineCookie(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return raw.trim();
}
String? parseCookieFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('Cookie file not found', path);
  }
  final pairs = <String>[];
  for (var line in file.readAsLinesSync()) {
    var l = line;
    if (l.startsWith('#HttpOnly_')) l = l.substring('#HttpOnly_'.length);
    if (l.trim().isEmpty || l.trimLeft().startsWith('#')) continue;
    final parts = l.split('\t');
    if (parts.length < 7) continue;
    final name = parts[5];
    final value = parts[6];
    pairs.add('$name=$value');
  }
  if (pairs.isEmpty) return null;
  return pairs.join('; ');
}
String? resolveCookieHeader({String? cookie, String? cookieFile}) {
  if (cookieFile != null && cookieFile.isNotEmpty) {
    return parseCookieFile(cookieFile);
  }
  return parseInlineCookie(cookie);
}

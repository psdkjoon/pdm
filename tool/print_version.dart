import 'dart:io';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'pubspec.yaml';
  final content = File(path).readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(content);
  if (match == null) {
    stderr.writeln('Could not find a version: field in $path');
    exit(1);
  }
  stdout.write(match.group(1));
}

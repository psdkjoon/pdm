import 'dart:convert';
import 'dart:io';

const _chunkSize = 76;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run tool/generate_payload.dart <payload_binary> <output_dart_file>');
    exit(1);
  }

  final payload = File(args[0]).readAsBytesSync();
  final encoded = base64.encode(payload);

  final chunks = <String>[];
  for (var i = 0; i < encoded.length; i += _chunkSize) {
    final end = (i + _chunkSize < encoded.length) ? i + _chunkSize : encoded.length;
    chunks.add("  '${encoded.substring(i, end)}',");
  }

  final buffer = StringBuffer()
    ..writeln('const List<String> pdmPayloadChunks = [')
    ..writeln(chunks.join('\n'))
    ..writeln('];');

  File(args[1]).writeAsStringSync(buffer.toString());
  stdout.writeln('Generated ${args[1]} (${payload.length}B payload)');
}

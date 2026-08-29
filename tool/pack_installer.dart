import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/pack_installer.dart <installer_stub> <payload> <output>',
    );
    exit(1);
  }

  final stub = File(args[0]).readAsBytesSync();
  final payload = File(args[1]).readAsBytesSync();

  final footer = ByteData(8)..setUint64(0, payload.length, Endian.big);

  final out = File(args[2]);
  final sink = out.openWrite();
  sink.add(stub);
  sink.add(payload);
  sink.add(footer.buffer.asUint8List());
  sink.close();

  stdout.writeln(
    'Packed ${args[2]}  (stub: ${stub.length}B, payload: ${payload.length}B)',
  );
}

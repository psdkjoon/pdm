import 'dart:io';

import 'package:pdata/pdata.dart';

const String _bakedVersion = String.fromEnvironment('PDM_VERSION');
const String _fallbackVersion = '3.0.0';

String pdmVersion() {
  if (_bakedVersion.isNotEmpty) return _bakedVersion;
  try {
    final uri = Platform.script.resolve('../pubspec.yaml');
    final file = File.fromUri(uri);
    if (!file.existsSync()) return _fallbackVersion;
    final data = pdataDecode(file.readAsStringSync(), PdataFormat.yaml);
    if (data is Map && data['version'] != null) {
      return data['version'].toString();
    }
    return _fallbackVersion;
  } catch (_) {
    return _fallbackVersion;
  }
}

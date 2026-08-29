import 'dart:io';

const String _bakedVersion = String.fromEnvironment('PDM_VERSION');

/// The running build's version, sourced from `pubspec.yaml`.
///
/// Compiled releases get it baked in at build time (see above). When running
/// straight from source (`dart run bin/pdm.dart`), it's read live from the
/// nearest `pubspec.yaml` instead, so `dart run` always reflects whatever
/// version is currently checked out.
String pdmVersion() {
  if (_bakedVersion.isNotEmpty) return _bakedVersion;

  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 6; i++) {
      final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
      if (pubspec.existsSync()) {
        final match = RegExp(
          r'^version:\s*(\S+)',
          multiLine: true,
        ).firstMatch(pubspec.readAsStringSync());
        if (match != null) return match.group(1)!;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}
  return 'unknown';
}

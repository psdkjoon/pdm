import 'dart:convert';
import 'dart:io';
import 'config.dart' show defaultStateDir;
import 'models.dart';
class TaskStore {
  final String path;
  TaskStore({String? path}) : path = path ?? _defaultPath();
  static String _defaultPath() => '${defaultStateDir()}/state.json';
  List<TaskRecord> load() {
    final file = File(path);
    if (!file.existsSync()) return [];
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! List) return [];
      return raw
          .map((e) => TaskRecord.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }
  void save(List<TaskRecord> tasks) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(
        tasks.map((t) => t.toJson()).toList(),
      ),
    );
    tmp.renameSync(path);
  }
}

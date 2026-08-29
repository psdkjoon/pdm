import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Reads/writes the manager's state file: `$XDG_STATE_HOME/pdm/state.json`
/// (falls back to `~/.local/state/pdm/state.json`).
class TaskStore {
  final File file;

  TaskStore(this.file);

  factory TaskStore.defaultLocation() {
    final xdgState = Platform.environment['XDG_STATE_HOME'];
    final home = Platform.environment['HOME'] ?? '.';
    final base = (xdgState != null && xdgState.isNotEmpty)
        ? xdgState
        : '$home/.local/state';
    final dir = Directory('$base/pdm');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return TaskStore(File('${dir.path}/state.json'));
  }

  List<TaskRecord> loadAll() {
    if (!file.existsSync()) return [];
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => TaskRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void saveAll(List<TaskRecord> tasks) {
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(tasks.map((t) => t.toJson()).toList()),
    );
    tmp.renameSync(file.path);
  }
}

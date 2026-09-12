import 'dart:convert';
import 'dart:io';

import 'config.dart' show defaultStateDir;
import 'models.dart';

class HistoryEntry {
  final String id;
  final String url;
  final String savePath;
  final DownloadStatus status;
  final int totalBytes;
  final int durationMs;
  final DateTime finishedAt;
  const HistoryEntry({
    required this.id,
    required this.url,
    required this.savePath,
    required this.status,
    required this.totalBytes,
    required this.durationMs,
    required this.finishedAt,
  });
  double get averageBytesPerSec =>
      durationMs > 0 ? totalBytes / (durationMs / 1000) : 0;
  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'savePath': savePath,
        'status': status.name,
        'totalBytes': totalBytes,
        'durationMs': durationMs,
        'finishedAt': finishedAt.toIso8601String(),
      };
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        url: j['url'] as String,
        savePath: j['savePath'] as String,
        status: statusFromString(j['status'] as String),
        totalBytes: j['totalBytes'] as int? ?? 0,
        durationMs: j['durationMs'] as int? ?? 0,
        finishedAt: DateTime.parse(j['finishedAt'] as String),
      );
}

class HistoryLog {
  final String path;
  HistoryLog({String? path}) : path = path ?? defaultHistoryPath();
  static String defaultHistoryPath() => '${defaultStateDir()}/history.jsonl';
  void append(HistoryEntry entry) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
    );
  }

  List<HistoryEntry> load({int? limit}) {
    final file = File(path);
    if (!file.existsSync()) return [];
    final entries = <HistoryEntry>[];
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        entries.add(
          HistoryEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (_) {}
    }
    entries.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    if (limit != null && entries.length > limit) {
      return entries.sublist(0, limit);
    }
    return entries;
  }

  void clear() {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}

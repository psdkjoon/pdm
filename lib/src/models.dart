/// Lifecycle states of a [DownloadTask].
enum DownloadStatus {
  queued,
  probing,
  downloading,
  paused,
  merging,
  completed,
  failed,
  canceled,
}

DownloadStatus statusFromString(String s) => DownloadStatus.values.firstWhere(
  (e) => e.name == s,
  orElse: () => DownloadStatus.failed,
);

/// One byte-range slice of a download, handled by its own HTTP connection.
class Segment {
  final int index;
  final int start;
  final int end;
  int downloaded;

  Segment({
    required this.index,
    required this.start,
    required this.end,
    this.downloaded = 0,
  });

  int get length => end - start + 1;
  int get remaining => length - downloaded;
  bool get isComplete => downloaded >= length;

  Map<String, dynamic> toJson() => {
    'index': index,
    'start': start,
    'end': end,
    'downloaded': downloaded,
  };

  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
    index: j['index'] as int,
    start: j['start'] as int,
    end: j['end'] as int,
    downloaded: j['downloaded'] as int,
  );
}

/// Persisted state for a single download, independent of the live [DownloadTask]
/// object — this is what gets written to disk so downloads survive restarts.
class TaskRecord {
  final String id;
  final String url;
  final String savePath;
  DownloadStatus status;
  int? totalBytes;
  bool supportsRange;
  int connections;
  List<Segment> segments;
  String? error;
  DateTime createdAt;
  DateTime updatedAt;

  TaskRecord({
    required this.id,
    required this.url,
    required this.savePath,
    this.status = DownloadStatus.queued,
    this.totalBytes,
    this.supportsRange = false,
    this.connections = 4,
    List<Segment>? segments,
    this.error,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : segments = segments ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get downloadedBytes =>
      segments.fold<int>(0, (sum, s) => sum + s.downloaded);

  double get progress {
    if (totalBytes == null || totalBytes == 0) return 0;
    return downloadedBytes / totalBytes!;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'savePath': savePath,
    'status': status.name,
    'totalBytes': totalBytes,
    'supportsRange': supportsRange,
    'connections': connections,
    'segments': segments.map((s) => s.toJson()).toList(),
    'error': error,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TaskRecord.fromJson(Map<String, dynamic> j) => TaskRecord(
    id: j['id'] as String,
    url: j['url'] as String,
    savePath: j['savePath'] as String,
    status: statusFromString(j['status'] as String),
    totalBytes: j['totalBytes'] as int?,
    supportsRange: j['supportsRange'] as bool? ?? false,
    connections: j['connections'] as int? ?? 4,
    segments: (j['segments'] as List)
        .map((e) => Segment.fromJson(e as Map<String, dynamic>))
        .toList(),
    error: j['error'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}

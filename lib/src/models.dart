enum DownloadStatus {
  queued,
  scheduled,
  probing,
  downloading,
  paused,
  verifying,
  completed,
  failed,
  canceled,
}

DownloadStatus statusFromString(String s) => DownloadStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => DownloadStatus.failed,
    );

class Schedule {
  final DateTime? at;
  final Duration? every;
  final bool onStartup;
  const Schedule({this.at, this.every, this.onStartup = false});
  bool get isSet => at != null || every != null || onStartup;
  Map<String, dynamic> toJson() => {
        'at': at?.toIso8601String(),
        'everyMs': every?.inMilliseconds,
        'onStartup': onStartup,
      };
  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        at: j['at'] != null ? DateTime.parse(j['at'] as String) : null,
        every: j['everyMs'] != null
            ? Duration(milliseconds: j['everyMs'] as int)
            : null,
        onStartup: j['onStartup'] as bool? ?? false,
      );
}

class DownloadRule {
  final String pattern;
  final String? saveDir;
  final int? connections;
  final String? proxy;
  final int? speedLimitBytesPerSec;
  final Map<String, String> headers;
  final String? onComplete;
  const DownloadRule({
    required this.pattern,
    this.saveDir,
    this.connections,
    this.proxy,
    this.speedLimitBytesPerSec,
    this.headers = const {},
    this.onComplete,
  });
  bool matches(String url) => RegExp(pattern).hasMatch(url);
  Map<String, dynamic> toJson() => {
        'pattern': pattern,
        if (saveDir != null) 'saveDir': saveDir,
        if (connections != null) 'connections': connections,
        if (proxy != null) 'proxy': proxy,
        if (speedLimitBytesPerSec != null) 'speedLimit': speedLimitBytesPerSec,
        if (headers.isNotEmpty) 'headers': headers,
        if (onComplete != null) 'onComplete': onComplete,
      };
  factory DownloadRule.fromJson(Map<String, dynamic> j) => DownloadRule(
        pattern: (j['pattern'] ?? j['match'] ?? '') as String,
        saveDir: (j['saveDir'] ?? j['dir']) as String?,
        connections: j['connections'] as int?,
        proxy: j['proxy'] as String?,
        speedLimitBytesPerSec:
            j['speedLimit'] is int ? j['speedLimit'] as int : null,
        headers: j['headers'] is Map
            ? (j['headers'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              )
            : const {},
        onComplete: j['onComplete'] as String?,
      );
}

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

class TaskOptions {
  final int connections;
  final Map<String, String> headers;
  final String? userAgent;
  final String? referer;
  final String? cookie;
  final String? cookieFile;
  final String? proxy;
  final String? proxyUser;
  final String? proxyPass;
  final List<String> proxyBypass;
  final int retries;
  final int retryDelayMs;
  final bool retryBackoff;
  final int timeoutSeconds;
  final int? speedLimitBytesPerSec;
  final String? checksumAlgo;
  final String? checksumValue;
  final String? authUser;
  final String? authPass;
  final bool insecure;
  final bool overwrite;
  final int priority;
  final int maxRedirects;
  final String? onComplete;
  final bool checkDiskSpace;
  const TaskOptions({
    this.connections = 4,
    this.headers = const {},
    this.userAgent,
    this.referer,
    this.cookie,
    this.cookieFile,
    this.proxy,
    this.proxyUser,
    this.proxyPass,
    this.proxyBypass = const [],
    this.retries = 3,
    this.retryDelayMs = 1000,
    this.retryBackoff = true,
    this.timeoutSeconds = 30,
    this.speedLimitBytesPerSec,
    this.checksumAlgo,
    this.checksumValue,
    this.authUser,
    this.authPass,
    this.insecure = false,
    this.overwrite = false,
    this.priority = 0,
    this.maxRedirects = 5,
    this.onComplete,
    this.checkDiskSpace = true,
  });
  TaskOptions mergeRule(DownloadRule rule) => TaskOptions(
        connections: rule.connections ?? connections,
        headers: {...headers, ...rule.headers},
        userAgent: userAgent,
        referer: referer,
        cookie: cookie,
        cookieFile: cookieFile,
        proxy: rule.proxy ?? proxy,
        proxyUser: proxyUser,
        proxyPass: proxyPass,
        proxyBypass: proxyBypass,
        retries: retries,
        retryDelayMs: retryDelayMs,
        retryBackoff: retryBackoff,
        timeoutSeconds: timeoutSeconds,
        speedLimitBytesPerSec:
            rule.speedLimitBytesPerSec ?? speedLimitBytesPerSec,
        checksumAlgo: checksumAlgo,
        checksumValue: checksumValue,
        authUser: authUser,
        authPass: authPass,
        insecure: insecure,
        overwrite: overwrite,
        priority: priority,
        maxRedirects: maxRedirects,
        onComplete: rule.onComplete ?? onComplete,
        checkDiskSpace: checkDiskSpace,
      );
  Map<String, dynamic> toJson() => {
        'connections': connections,
        'headers': headers,
        'userAgent': userAgent,
        'referer': referer,
        'cookie': cookie,
        'cookieFile': cookieFile,
        'proxy': proxy,
        'proxyUser': proxyUser,
        'proxyPass': proxyPass,
        'proxyBypass': proxyBypass,
        'retries': retries,
        'retryDelayMs': retryDelayMs,
        'retryBackoff': retryBackoff,
        'timeoutSeconds': timeoutSeconds,
        'speedLimitBytesPerSec': speedLimitBytesPerSec,
        'checksumAlgo': checksumAlgo,
        'checksumValue': checksumValue,
        'authUser': authUser,
        'authPass': authPass,
        'insecure': insecure,
        'overwrite': overwrite,
        'priority': priority,
        'maxRedirects': maxRedirects,
        'onComplete': onComplete,
        'checkDiskSpace': checkDiskSpace,
      };
  factory TaskOptions.fromJson(Map<String, dynamic> j) => TaskOptions(
        connections: j['connections'] as int? ?? 4,
        headers: (j['headers'] as Map?)?.cast<String, String>() ?? const {},
        userAgent: j['userAgent'] as String?,
        referer: j['referer'] as String?,
        cookie: j['cookie'] as String?,
        cookieFile: j['cookieFile'] as String?,
        proxy: j['proxy'] as String?,
        proxyUser: j['proxyUser'] as String?,
        proxyPass: j['proxyPass'] as String?,
        proxyBypass: (j['proxyBypass'] as List?)?.cast<String>() ?? const [],
        retries: j['retries'] as int? ?? 3,
        retryDelayMs: j['retryDelayMs'] as int? ?? 1000,
        retryBackoff: j['retryBackoff'] as bool? ?? true,
        timeoutSeconds: j['timeoutSeconds'] as int? ?? 30,
        speedLimitBytesPerSec: j['speedLimitBytesPerSec'] as int?,
        checksumAlgo: j['checksumAlgo'] as String?,
        checksumValue: j['checksumValue'] as String?,
        authUser: j['authUser'] as String?,
        authPass: j['authPass'] as String?,
        insecure: j['insecure'] as bool? ?? false,
        overwrite: j['overwrite'] as bool? ?? false,
        priority: j['priority'] as int? ?? 0,
        maxRedirects: j['maxRedirects'] as int? ?? 5,
        onComplete: j['onComplete'] as String?,
        checkDiskSpace: j['checkDiskSpace'] as bool? ?? true,
      );
}

class TaskRecord {
  final String id;
  final String url;
  final String savePath;
  DownloadStatus status;
  int? totalBytes;
  bool supportsRange;
  TaskOptions options;
  List<Segment> segments;
  String? error;
  DateTime createdAt;
  DateTime updatedAt;
  bool startPaused;
  Schedule? schedule;
  TaskRecord({
    required this.id,
    required this.url,
    required this.savePath,
    this.status = DownloadStatus.queued,
    this.totalBytes,
    this.supportsRange = false,
    TaskOptions? options,
    List<Segment>? segments,
    this.error,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.startPaused = false,
    this.schedule,
  })  : options = options ?? const TaskOptions(),
        segments = segments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
  int get connections => options.connections;
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
        'options': options.toJson(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'startPaused': startPaused,
        'schedule': schedule?.toJson(),
      };
  factory TaskRecord.fromJson(Map<String, dynamic> j) => TaskRecord(
        id: j['id'] as String,
        url: j['url'] as String,
        savePath: j['savePath'] as String,
        status: statusFromString(j['status'] as String),
        totalBytes: j['totalBytes'] as int?,
        supportsRange: j['supportsRange'] as bool? ?? false,
        options: j['options'] != null
            ? TaskOptions.fromJson(
                (j['options'] as Map).cast<String, dynamic>(),
              )
            : const TaskOptions(),
        segments: (j['segments'] as List)
            .map((e) => Segment.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        error: j['error'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        startPaused: j['startPaused'] as bool? ?? false,
        schedule: j['schedule'] != null
            ? Schedule.fromJson((j['schedule'] as Map).cast<String, dynamic>())
            : null,
      );
}

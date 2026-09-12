import 'dart:io';

import 'package:pdata/pdata.dart';

import 'models.dart' show DownloadRule;

class PdmConfig {
  final int connections;
  final int maxConcurrentTasks;
  final int retries;
  final int retryDelayMs;
  final bool retryBackoff;
  final int timeoutSeconds;
  final int? speedLimitBytesPerSec;
  final int? globalSpeedLimitBytesPerSec;
  final int maxRedirects;
  final bool insecure;
  final String downloadDir;
  final String theme;
  final bool color;
  final String daemonHost;
  final int daemonPort;
  final String socketPath;
  final String? proxy;
  final String? proxyUser;
  final String? proxyPass;
  final List<String> proxyBypass;
  final Map<String, String> onCompleteAliases;
  final List<DownloadRule> rules;
  final bool notifications;
  final bool checkDiskSpace;
  const PdmConfig({
    this.connections = 4,
    this.maxConcurrentTasks = 3,
    this.retries = 3,
    this.retryDelayMs = 1000,
    this.retryBackoff = true,
    this.timeoutSeconds = 30,
    this.speedLimitBytesPerSec,
    this.globalSpeedLimitBytesPerSec,
    this.maxRedirects = 5,
    this.insecure = false,
    this.downloadDir = '~/Downloads',
    this.theme = 'default',
    this.color = true,
    this.daemonHost = '127.0.0.1',
    this.daemonPort = 7420,
    this.socketPath = '~/.local/state/pdm/pdm.sock',
    this.proxy,
    this.proxyUser,
    this.proxyPass,
    this.proxyBypass = const [],
    this.onCompleteAliases = const {},
    this.rules = const [],
    this.notifications = false,
    this.checkDiskSpace = true,
  });
  static const PdmConfig defaults = PdmConfig();
  Map<String, dynamic> toJson() => {
        'connections': connections,
        'maxConcurrentTasks': maxConcurrentTasks,
        'retries': retries,
        'retryDelay': retryDelayMs,
        'retryBackoff': retryBackoff,
        'timeout': timeoutSeconds,
        'speedLimit': speedLimitBytesPerSec,
        'globalSpeedLimit': globalSpeedLimitBytesPerSec,
        'maxRedirects': maxRedirects,
        'insecure': insecure,
        'downloadDir': downloadDir,
        'theme': theme,
        'color': color,
        'daemonHost': daemonHost,
        'daemonPort': daemonPort,
        'socketPath': socketPath,
        'proxy': proxy,
        'proxyUser': proxyUser,
        'proxyPass': proxyPass,
        'proxyBypass': proxyBypass,
        'onCompleteAliases': onCompleteAliases,
        'rules': rules.map((r) => r.toJson()).toList(),
        'notifications': notifications,
        'checkDiskSpace': checkDiskSpace,
      };
  factory PdmConfig.fromMap(Map<String, dynamic> m) => PdmConfig(
        connections:
            m.getInt('connections', defaultValue: defaults.connections),
        maxConcurrentTasks: m.getInt(
          'maxConcurrentTasks',
          defaultValue: defaults.maxConcurrentTasks,
        ),
        retries: m.getInt('retries', defaultValue: defaults.retries),
        retryDelayMs:
            m.getInt('retryDelay', defaultValue: defaults.retryDelayMs),
        retryBackoff: m.getBool(
          'retryBackoff',
          defaultValue: defaults.retryBackoff,
        ),
        timeoutSeconds:
            m.getInt('timeout', defaultValue: defaults.timeoutSeconds),
        speedLimitBytesPerSec:
            m['speedLimit'] == null ? null : m.getInt('speedLimit'),
        globalSpeedLimitBytesPerSec:
            m['globalSpeedLimit'] == null ? null : m.getInt('globalSpeedLimit'),
        maxRedirects:
            m.getInt('maxRedirects', defaultValue: defaults.maxRedirects),
        insecure: m.getBool('insecure', defaultValue: defaults.insecure),
        downloadDir:
            m.getString('downloadDir', defaultValue: defaults.downloadDir),
        theme: m.getString('theme', defaultValue: defaults.theme),
        color: m.getBool('color', defaultValue: defaults.color),
        daemonHost:
            m.getString('daemonHost', defaultValue: defaults.daemonHost),
        daemonPort: m.getInt('daemonPort', defaultValue: defaults.daemonPort),
        socketPath:
            m.getString('socketPath', defaultValue: defaults.socketPath),
        proxy: m['proxy'] as String?,
        proxyUser: m['proxyUser'] as String?,
        proxyPass: m['proxyPass'] as String?,
        proxyBypass: _stringList(m['proxyBypass']),
        onCompleteAliases: _stringMap(m['onCompleteAliases']),
        rules: _ruleList(m['rules']),
        notifications: m.getBool(
          'notifications',
          defaultValue: defaults.notifications,
        ),
        checkDiskSpace: m.getBool(
          'checkDiskSpace',
          defaultValue: defaults.checkDiskSpace,
        ),
      );
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

Map<String, String> _stringMap(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
}

List<DownloadRule> _ruleList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => DownloadRule.fromJson(m.cast<String, dynamic>()))
      .toList();
}

String homeDir() {
  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null && profile.isNotEmpty) return profile;
    final drive = Platform.environment['HOMEDRIVE'];
    final path = Platform.environment['HOMEPATH'];
    if (drive != null && path != null) return '$drive$path';
    return '.';
  }
  return Platform.environment['HOME'] ?? '.';
}

String defaultStateDir() {
  final xdg = Platform.environment['XDG_STATE_HOME'];
  if (xdg != null && xdg.isNotEmpty) return '$xdg/pdm';
  return '${homeDir()}/.local/state/pdm';
}

String defaultConfigPath() {
  final envPath = Platform.environment['PDM_CONFIG_PATH'];
  if (envPath != null && envPath.isNotEmpty) return expandHome(envPath);
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) return '$appData/pdm/pdm.yaml';
  }
  return '${homeDir()}/.config/pdm/pdm.yaml';
}

String expandHome(String path) {
  if (!path.startsWith('~')) return path;
  return path.replaceFirst('~', homeDir());
}

PdataFormat formatFromName(String name) {
  switch (name.toLowerCase()) {
    case 'json':
      return PdataFormat.json;
    case 'toml':
      return PdataFormat.toml;
    case 'yaml':
    case 'yml':
      return PdataFormat.yaml;
    default:
      throw ArgumentError('Unknown format "$name" (use yaml, toml, or json)');
  }
}

PdmConfig loadConfig({String? path}) {
  final resolved = expandHome(path ?? defaultConfigPath());
  final file = File(resolved);
  if (!file.existsSync()) return PdmConfig.defaults;
  final format = pdataFormatFromExtension(resolved) ?? PdataFormat.yaml;
  final raw = pdataDecode(file.readAsStringSync(), format);
  if (raw is! Map<String, dynamic>) return PdmConfig.defaults;
  return PdmConfig.fromMap(raw);
}

String dumpDefaultConfig({PdataFormat format = PdataFormat.yaml}) {
  return pdataEncode(PdmConfig.defaults.toJson(), format, pretty: true);
}

void writeDefaultConfig(
  String outputPath, {
  PdataFormat? format,
  bool force = false,
}) {
  final resolved = expandHome(outputPath);
  final resolvedFormat =
      format ?? pdataFormatFromExtension(resolved) ?? PdataFormat.yaml;
  final file = File(resolved);
  if (file.existsSync() && !force) {
    throw StateError('$resolved already exists. Use --force to overwrite.');
  }
  pdataWriteFile(
    resolved,
    PdmConfig.defaults.toJson(),
    format: resolvedFormat,
    pretty: true,
  );
}

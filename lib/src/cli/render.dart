import 'dart:io';
import '../models.dart';
import 'theme.dart';
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
String formatSpeed(int bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';
String formatDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}
void printProgressLine(
  TaskRecord record,
  CliTheme theme, {
  int? bytesPerSecond,
}) {
  final pct = (record.progress * 100).toStringAsFixed(1);
  final bar = theme.bar(record.progress);
  final downloaded = formatBytes(record.downloadedBytes);
  final total =
      record.totalBytes != null ? formatBytes(record.totalBytes!) : '?';
  final speed = bytesPerSecond != null ? ' ${formatSpeed(bytesPerSecond)}' : '';
  stdout.write('\r$bar $pct% ($downloaded/$total)$speed   ');
}
void printTaskTable(List<TaskRecord> records, CliTheme theme) {
  if (records.isEmpty) {
    stdout.writeln(theme.muted('No tasks.'));
    return;
  }
  final idW = 8, statusW = 12;
  stdout.writeln(
    theme.bold(
      '${'ID'.padRight(idW)}  ${'STATUS'.padRight(statusW)}  ${'PROGRESS'.padRight(9)}  NAME',
    ),
  );
  for (final r in records) {
    final pct = '${(r.progress * 100).toStringAsFixed(0)}%';
    final name =
        r.savePath.contains('/') ? r.savePath.split('/').last : r.savePath;
    final paddedStatus = r.status.name.padRight(statusW);
    final statusColored = _colorStatus(r.status, theme, paddedStatus);
    stdout.writeln(
      '${r.id.padRight(idW)}  $statusColored  ${pct.padRight(9)}  $name',
    );
  }
}
String _colorStatus(DownloadStatus status, CliTheme theme, String text) {
  switch (status) {
    case DownloadStatus.completed:
      return theme.success(text);
    case DownloadStatus.failed:
    case DownloadStatus.canceled:
      return theme.error(text);
    case DownloadStatus.paused:
      return theme.warn(text);
    default:
      return theme.info(text);
  }
}

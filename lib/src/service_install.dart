import 'dart:io';
import 'config.dart' show homeDir;
import 'daemon/daemon_client.dart' show resolvePdmdCommand;
class ServiceInstallResult {
  final bool success;
  final String message;
  const ServiceInstallResult(this.success, this.message);
}
String _windowsTaskName() => 'pdm daemon';
String _systemdUnitPath() => '${homeDir()}/.config/systemd/user/pdmd.service';
String _launchdPlistPath() =>
    '${homeDir()}/Library/LaunchAgents/dev.pdm.daemon.plist';
String _joinCommand(String executable, List<String> args) =>
    [executable, ...args].join(' ');
String _systemdUnit(String executable, List<String> args) {
  final exec = _joinCommand(executable, args);
  return '[Unit]\n'
      'Description=pdm download manager daemon\n\n'
      '[Service]\n'
      'ExecStart=$exec\n'
      'Restart=on-failure\n\n'
      '[Install]\n'
      'WantedBy=default.target\n';
}
String _launchdPlist(String executable, List<String> args) {
  final items = [
    executable,
    ...args,
  ].map((a) => '<string>$a</string>').join();
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
      '<plist version="1.0">\n'
      '<dict>\n'
      '<key>Label</key><string>dev.pdm.daemon</string>\n'
      '<key>ProgramArguments</key><array>$items</array>\n'
      '<key>RunAtLoad</key><true/>\n'
      '<key>KeepAlive</key><true/>\n'
      '</dict>\n'
      '</plist>\n';
}
Future<ServiceInstallResult> installDaemonService() async {
  final (executable, args) = resolvePdmdCommand();
  if (Platform.isWindows) {
    final command = _joinCommand(executable, args);
    final result = await Process.run('schtasks', [
      '/create',
      '/tn',
      _windowsTaskName(),
      '/sc',
      'onlogon',
      '/rl',
      'limited',
      '/tr',
      command,
      '/f',
    ]);
    if (result.exitCode != 0) {
      return ServiceInstallResult(false, result.stderr.toString().trim());
    }
    return ServiceInstallResult(
      true,
      'Registered a logon task named "${_windowsTaskName()}".',
    );
  }
  if (Platform.isMacOS) {
    final plistPath = _launchdPlistPath();
    File(plistPath).parent.createSync(recursive: true);
    File(plistPath).writeAsStringSync(_launchdPlist(executable, args));
    final result = await Process.run('launchctl', ['load', '-w', plistPath]);
    if (result.exitCode != 0) {
      return ServiceInstallResult(false, result.stderr.toString().trim());
    }
    return ServiceInstallResult(true, 'Installed and loaded $plistPath');
  }
  final unitPath = _systemdUnitPath();
  File(unitPath).parent.createSync(recursive: true);
  File(unitPath).writeAsStringSync(_systemdUnit(executable, args));
  final reload = await Process.run('systemctl', ['--user', 'daemon-reload']);
  if (reload.exitCode != 0) {
    return ServiceInstallResult(false, reload.stderr.toString().trim());
  }
  final enable = await Process.run('systemctl', [
    '--user',
    'enable',
    '--now',
    'pdmd.service',
  ]);
  if (enable.exitCode != 0) {
    return ServiceInstallResult(false, enable.stderr.toString().trim());
  }
  return ServiceInstallResult(true, 'Installed and started $unitPath');
}
Future<ServiceInstallResult> uninstallDaemonService() async {
  if (Platform.isWindows) {
    final result = await Process.run('schtasks', [
      '/delete',
      '/tn',
      _windowsTaskName(),
      '/f',
    ]);
    if (result.exitCode != 0) {
      return ServiceInstallResult(false, result.stderr.toString().trim());
    }
    return ServiceInstallResult(
      true,
      'Removed the "${_windowsTaskName()}" logon task.',
    );
  }
  if (Platform.isMacOS) {
    final plistPath = _launchdPlistPath();
    await Process.run('launchctl', ['unload', '-w', plistPath]);
    final file = File(plistPath);
    if (file.existsSync()) file.deleteSync();
    return ServiceInstallResult(true, 'Unloaded and removed $plistPath');
  }
  final unitPath = _systemdUnitPath();
  await Process.run('systemctl', ['--user', 'disable', '--now', 'pdmd.service']);
  final file = File(unitPath);
  if (file.existsSync()) file.deleteSync();
  await Process.run('systemctl', ['--user', 'daemon-reload']);
  return ServiceInstallResult(true, 'Disabled and removed $unitPath');
}

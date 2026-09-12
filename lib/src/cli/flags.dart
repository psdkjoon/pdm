enum FlagKind { string, int, flag, multiString }
class FlagDef {
  final String long;
  final String short;
  final FlagKind kind;
  final String help;
  final String? defaultValue;
  const FlagDef(this.long, this.short, this.kind, this.help, {this.defaultValue});
}
const globalFlags = <FlagDef>[
  FlagDef('verbose', 'v', FlagKind.flag, 'Print extra diagnostic output'),
  FlagDef('quiet', 'q', FlagKind.flag, 'Suppress non-essential output'),
  FlagDef('json', 'j', FlagKind.flag, 'Machine-readable JSON output'),
  FlagDef('daemon-host', 'H', FlagKind.string, 'Daemon TCP host (Windows)'),
  FlagDef('daemon-port', 'P', FlagKind.string, 'Daemon TCP port (Windows)'),
  FlagDef('socket-path', 's', FlagKind.string, 'Daemon unix socket path (Linux)'),
  FlagDef('no-spawn', 'n', FlagKind.flag, 'Fail instead of auto-spawning the daemon'),
  FlagDef('config', 'g', FlagKind.string, 'Path to config file'),
  FlagDef('theme', 'T', FlagKind.string, 'Progress/output theme: default, rainbow, catppuccin'),
  FlagDef('no-color', 'N', FlagKind.flag, 'Disable ANSI colors'),
  FlagDef('help', 'h', FlagKind.flag, 'Show help for this command'),
];
const addFlags = <FlagDef>[
  FlagDef('output', 'o', FlagKind.string, 'Save path for the downloaded file'),
  FlagDef('connections', 'c', FlagKind.string, 'Number of concurrent connections/segments'),
  FlagDef('foreground', 'f', FlagKind.flag, 'Block in this process with a live progress bar'),
  FlagDef('background', 'b', FlagKind.flag, 'Run via the daemon and return immediately (default)'),
  FlagDef('header', 'e', FlagKind.multiString, 'Custom header "Key: Value" (repeatable)'),
  FlagDef('user-agent', 'u', FlagKind.string, 'Custom User-Agent header'),
  FlagDef('referer', 'R', FlagKind.string, 'Referer header'),
  FlagDef('cookie', 'C', FlagKind.string, 'Inline cookie string "key=value; key2=value2"'),
  FlagDef('cookie-file', 'J', FlagKind.string, 'Netscape-format cookie file (wins over --cookie)'),
  FlagDef('proxy', 'p', FlagKind.string, 'HTTP proxy URL'),
  FlagDef('proxy-user', 'Q', FlagKind.string, 'Proxy basic-auth username'),
  FlagDef('proxy-pass', 'W', FlagKind.string, 'Proxy basic-auth password'),
  FlagDef('retries', 'r', FlagKind.string, 'Retry attempts per segment'),
  FlagDef('retry-delay', 'd', FlagKind.string, 'Delay between retries in milliseconds'),
  FlagDef('linear-retries', 'L', FlagKind.flag, 'Disable exponential backoff between retries'),
  FlagDef('timeout', 't', FlagKind.string, 'Connection/read timeout in seconds'),
  FlagDef('speed-limit', 'l', FlagKind.string, 'Max download speed, e.g. 2M, 500K'),
  FlagDef('checksum', 'k', FlagKind.string, 'Expected checksum "algo:hex", e.g. sha256:abc123'),
  FlagDef('auth-user', 'U', FlagKind.string, 'Basic auth username'),
  FlagDef('auth-pass', 'w', FlagKind.string, 'Basic auth password'),
  FlagDef('insecure', 'i', FlagKind.flag, 'Skip TLS certificate verification'),
  FlagDef('overwrite', 'O', FlagKind.flag, 'Overwrite an existing file at the save path'),
  FlagDef('start-paused', 'x', FlagKind.flag, 'Add the task without starting it'),
  FlagDef('priority', 'y', FlagKind.string, 'Queue priority (higher runs first)'),
  FlagDef('max-redirects', 'm', FlagKind.string, 'Maximum redirects to follow'),
  FlagDef('at', 'a', FlagKind.string, 'Schedule start time: ISO date/time, "HH:mm", or "+<duration>"'),
  FlagDef('every', 'E', FlagKind.string, 'Repeat this download on an interval, e.g. 1d, 6h, 30m'),
  FlagDef('on-startup', 'S', FlagKind.flag, 'Defer this download until the daemon next starts'),
  FlagDef('on-complete', 'G', FlagKind.string, 'Command/alias to run when the download finishes'),
  FlagDef('allow-duplicate', 'D', FlagKind.flag, 'Allow adding a task with a duplicate url/save path'),
  FlagDef('file', 'B', FlagKind.string, 'Batch-add every URL (one per line) from this file'),
];
const listFlags = <FlagDef>[
  FlagDef('status', 'S', FlagKind.string, 'Filter by status'),
  FlagDef('sort', 't', FlagKind.string, 'Sort field: created, updated, progress, name'),
  FlagDef('reverse', 'R', FlagKind.flag, 'Reverse the sort order'),
  FlagDef('limit', 'L', FlagKind.string, 'Maximum number of rows to show'),
];
const taskActionFlags = <FlagDef>[
  FlagDef('all', 'A', FlagKind.flag, 'Apply to every matching task instead of one id'),
  FlagDef('force', 'F', FlagKind.flag, 'Skip confirmation prompts'),
];
const removeOnlyFlags = <FlagDef>[
  FlagDef('delete-file', 'D', FlagKind.flag, 'Also delete the downloaded file'),
];
const watchFlags = <FlagDef>[
  FlagDef('interval', 'I', FlagKind.string, 'Refresh interval in milliseconds'),
  FlagDef('no-bar', 'B', FlagKind.flag, 'Print plain progress lines instead of a bar'),
];
const configFlags = <FlagDef>[
  FlagDef('format', 'f', FlagKind.string, 'Output format: yaml, toml, json'),
  FlagDef('output', 'o', FlagKind.string, 'Write to file instead of stdout'),
  FlagDef('force', 'F', FlagKind.flag, 'Overwrite an existing file'),
];
const daemonFlags = <FlagDef>[
  FlagDef('foreground', 'f', FlagKind.flag, 'Run the daemon attached, for debugging'),
];
const historyFlags = <FlagDef>[
  FlagDef('limit', 'L', FlagKind.string, 'Maximum number of entries to show'),
  FlagDef('clear', 'C', FlagKind.flag, 'Clear the history log'),
];
const completionFlags = <FlagDef>[];
const Map<String, List<FlagDef>> commandFlags = {
  'add': addFlags,
  'list': listFlags,
  'pause': taskActionFlags,
  'resume': taskActionFlags,
  'cancel': taskActionFlags,
  'remove': [...taskActionFlags, ...removeOnlyFlags],
  'watch': watchFlags,
  'config': configFlags,
  'daemon': daemonFlags,
  'history': historyFlags,
  'completion': completionFlags,
};

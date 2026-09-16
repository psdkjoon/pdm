# pdm

psdk's download manager. Multi-connection downloads, a background daemon
so they survive closing the terminal, resume on interrupt, scheduling,
per-URL rules, and shell completion generated straight from the flag
definitions.

Pure Dart, no third-party deps beyond `pdata` for config parsing.

## Install

Grab a self-contained installer from the [releases
page](https://github.com/psdkjoon/pdm/releases/latest), check it against
`SHA256SUMS`, run it.

```bash
sudo ./pdm-linux-x64      # installs to /usr/bin
./pdm-linux-x64 --user    # or to ~/.local/bin instead, no sudo needed
```

On Windows just run `pdm-windows-x64.exe` — it installs itself under
`%LOCALAPPDATA%\Programs\pdm` and adds itself to PATH.

Uninstall the same way: `./pdm-linux-x64 uninstall` (`--keep-config` if
you want to keep your config and history around).

Shell completion: `pdm completion bash` / `pdm completion zsh`, or just
`pdm completion` to auto-detect from `$SHELL`.

## Usage

```bash
pdm add <url>                    # runs in the background by default
pdm add <url> -f                 # or block here with a progress bar
pdm add <url1> <url2> <url3>     # add a bunch at once
pdm add <url> --at 22:00         # start later
pdm add <url> --every 1d         # re-download on a schedule
pdm add <url> --on-complete shutdown
pdm list
pdm pause <id> / resume <id> / cancel <id> / remove <id>
pdm watch <id>
pdm daemon start|stop|status|enable|disable
pdm history
```

`pdm help <command>` for the full flag list — every flag has a short and
a long form. `pause`/`resume`/`cancel`/`remove` all take multiple ids or
`--all`.

`pdm daemon enable` sets the daemon to start on its own (systemd user
service on Linux, launchd on macOS, a logon task on Windows).

## Config

Lives at `~/.config/pdm/pdm.yaml` by default (`$PDM_CONFIG_PATH` to
override), yaml/toml/json depending on the extension. Generate a starting
one with:

```bash
pdm config dump --output ~/.config/pdm/pdm.yaml
```

CLI flags beat the config file, the config file beats built-in defaults.

Per-URL overrides via regex, checked top to bottom:

```yaml
rules:
  - pattern: "example\\.com/videos/"
    saveDir: "~/Videos"
    connections: 16
  - pattern: "\\.iso$"
    saveDir: "~/ISOs"
    proxy: "http://127.0.0.1:8080"
```

`--on-complete <cmd>` runs when a download finishes. `shutdown`,
`restart`, `sleep`, `hibernate`, `lock` are built in, or define your own
in `onCompleteAliases` — `{id}`, `{url}`, `{path}`, `{status}` get
substituted in.

## As a library

```dart
import 'package:pdm/pdm.dart';

final manager = DownloadManager();
manager.add(
  'https://example.com/file.iso',
  options: const TaskOptions(connections: 8, retries: 5),
  schedule: Schedule(every: Duration(days: 1)),
);
```

`lib/pdm.dart` has the full exported surface.

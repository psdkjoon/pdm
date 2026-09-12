# pdm
### psdk download manager

config-able 

## Install

grab a self-contained installer from the [releases page](https://github.com/psdkjoon/pdm/releases/latest),
verify it against the published `SHA256SUMS`, and run it:

- `pdm-linux-x64`
- `pdm-windows-x64.exe`

Each installer embeds both `pdm` and its background daemon `pdmd`. On
Linux it installs to `/usr/bin` by default, so you'll usually need:

```bash
sudo ./pdm-linux-x64
```

If you'd rather not use `sudo`, install to your user directory instead
(make sure `~/.local/bin` is on your `PATH`):

```bash
./pdm-linux-x64 --user
```

On Windows, run `pdm-windows-x64.exe`; it installs under
`%LOCALAPPDATA%\Programs\pdm` and adds itself to your user `PATH`.

## Uninstall

To remove pdm later:

```bash
sudo ./pdm-linux-x64 uninstall   # or: ./pdm-linux-x64 uninstall --user
```

Set up tab completion (installs into the system completion directory:

```bash
pdm completion bash   # or: pdm completion zsh
```

## Usage

```bash
pdm add <url> [-o <output>] [-c <connections>] [-f|--foreground] [...]
pdm add <url> --at 22:00              # start at a specific time
pdm add <url> --every 1d              # re-download on an interval
pdm add <url> --on-startup            # wait for the daemon to next start
pdm add <url> --on-complete shutdown  # run a hook when it finishes
pdm add --file urls.txt               # batch-add every URL in a file
pdm list [--status <status>] [--sort <field>]
pdm pause <id>
pdm resume <id>
pdm cancel <id>
pdm remove <id> [--delete-file]
pdm watch <id>
pdm daemon start|stop|status|enable|disable
pdm history [--limit <n>] [--clear]
pdm completion bash|zsh [--user] [--print]
pdm config dump [--format yaml|toml|json] [--output <path>]
pdm help [<command>]
```

Downloads run in the **background** by default (via a detached daemon) so
they survive closing the terminal. Pass `-f`/`--foreground` to `add` to
block in the current process with a live progress bar instead.

`pdm daemon enable` registers the daemon to start automatically: a
systemd user service on Linux or a logon scheduled task on Windows,
`pdm daemon disable` removes it.

Run `pdm help <command>` for the full flag list of any command.
Each flag has both a long and a short form.

## Scheduling

- `--at <time>` — start once at an absolute time (`2026-12-25T09:00`,
  `22:00`) or a relative offset (`+30m`, `+2h`, `+1d`).
- `--every <duration>` — after each successful run, re-queue the same
  download again after the given interval (`30m`, `6h`, `1d`).
- `--on-startup` — hold the task until the next time the daemon starts,
  regardless of time.

These can be combined, e.g. `--on-startup --every 1d` runs once at the
next daemon start and then daily after that.

## On-complete hooks

`--on-complete <command>` runs a shell command when a download finishes
(success or failure). A few cross-platform built-ins are available —
`shutdown`, `restart`, `sleep`, `hibernate`, `lock` — or define your own
aliases in the config file:

```yaml
onCompleteAliases:
  backup: "rsync -a {path} /mnt/backup/"
  ding: "notify-send 'Download done' '{path}'"
```

`{id}`, `{url}`, `{path}`, and `{status}` are substituted into the command.
Anything that isn't a built-in or an alias is run as-is.

## Download rules

Regex-matched per-URL overrides, checked in order, in the config file:

```yaml
rules:
  - pattern: "example\\.com/videos/"
    saveDir: "~/Videos"
    connections: 16
  - pattern: "\\.iso$"
    saveDir: "~/ISOs"
    proxy: "http://127.0.0.1:8080"
```

The first matching rule's `saveDir`/`connections`/`proxy`/`speedLimit`/
`headers`/`onComplete` override the request's own values.

## Proxy

Set a default proxy (and optional auth/bypass list) in the config file,
or per-download with `--proxy`/`--proxy-user`/`--proxy-pass`:

```yaml
proxy: "http://127.0.0.1:8080"
proxyUser: "me"
proxyPass: "secret"
proxyBypass: ["localhost", "internal.example.com"]
```

## Config

Config is read from `$PDM_CONFIG_PATH`, or `~/.config/pdm/pdm.yaml` by
default (`%APPDATA%\pdm\pdm.yaml` on Windows), in YAML, TOML, or JSON
(chosen by extension). Generate a starting point with:

```bash
pdm config dump --format yaml --output ~/.config/pdm/pdm.yaml
```

Precedence: CLI flag > config file > built-in default.

## Library usage

```dart
import 'package:pdm/pdm.dart';

final manager = DownloadManager();
final task = manager.add(
  'https://example.com/file.iso',
  options: const TaskOptions(connections: 8, retries: 5),
  schedule: Schedule(every: Duration(days: 1)),
);
```

See `lib/pdm.dart` for the full public library surface.


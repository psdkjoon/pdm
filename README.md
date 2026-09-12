# pdm

psdk download manager — library and CLI. Works on Linux and Windows.

Segmented, resumable, multi-connection downloads. Runs in the background
by default via a lightweight daemon, or in the foreground with a live
progress bar. Config file support (YAML/TOML/JSON), cookies, checksums,
proxies, speed limiting, scheduling, on-complete hooks, regex-based
per-site rules, and themeable output.

## Install

```bash
dart pub global activate pdm
```

Or grab a self-contained installer (no internet needed at install time)
from the [releases page](https://github.com/psdkjoon/pdm/releases/latest):

- `pdm-linux-x64`
- `pdm-windows-x64.exe`

Each installer embeds both `pdm` and its background daemon `pdmd`.

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
pdm completion bash|zsh
pdm config dump [--format yaml|toml|json] [--output <path>]
pdm help [<command>]
```

Downloads run in the **background** by default (via a detached daemon) so
they survive closing the terminal. Pass `-f`/`--foreground` to `add` to
block in the current process with a live progress bar instead.

`pdm daemon enable` registers the daemon to start automatically: a
systemd user service on Linux, a logon scheduled task on Windows, or a
launchd agent on macOS. `pdm daemon disable` removes it.

Run `pdm help <command>` for the full flag list of any command. Every
flag has both a long and a short form.

## Scheduling

- `--at <time>` — start once at an absolute time (`2026-12-25T09:00`,
  `22:00`) or a relative offset (`+30m`, `+2h`, `+1d`).
- `--every <duration>` — after each successful run, re-queue the same
  download again after the given interval (`30m`, `6h`, `1d`).
- `--on-startup` — hold the task until the next time the daemon starts,
  regardless of wall-clock time.

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

See `CLAUDE.md` / `AGENT.md` for architecture notes if you're contributing.


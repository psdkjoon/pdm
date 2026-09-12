## 3.0.0

- Fixed: `pdm watch <id>` and `pdm add <url>` (foreground mode) could hang
  forever if the daemon connection dropped mid-download (e.g. the daemon
  crashed, or `pdm daemon stop` ran concurrently) — the event-stream
  listeners had no `onDone`/`onError` handling, so the completer driving
  the command's exit code was never guaranteed to resolve. Both now exit
  cleanly with an error message when the connection is lost.
- Fixed: `printTaskTable`/`pdm history` extracted the filename from a
  save path by splitting on `/` only, so a Windows path (`C:\...\file`)
  would display in full instead of just the filename. Both now share a
  single `basename()` helper that normalizes both separators.
- Fixed: `pdm pause <id>` / `pdm cancel <id>` could deadlock the daemon.
  `DownloadTask.pause()`/`cancel()` canceled each active segment's HTTP
  subscription and then awaited a completer that, under a specific race
  (the cancel landing while a chunk was mid-wait inside the speed
  limiter), was never completed — so `run()` never returned, `pause()`/
  `cancel()` hung, and the daemon's request handler would eventually
  time out without ever resolving the task's state. Also fixed the same
  two methods iterating `_subs` while `_runSegment` could concurrently
  remove from it, which could throw `ConcurrentModificationError`.
- Fixed: `pdm daemon enable` and background auto-spawn (`pdm add` without
  `--foreground`) silently failing once installed as a compiled binary,
  because daemon-path resolution depended on `Platform.script`, which is
  meaningless in a compiled executable. Now resolves `pdmd`/`pdmd.exe` as
  a sibling of the running `pdm` binary, with a `PDMD_PATH` override.
- Fixed: `pdmd` not shutting down cleanly on SIGTERM (the server handle
  was discarded, so `stop()` was never called and the unix socket was
  never released).
- Fixed: `pdm version` always printing the hardcoded fallback version
  after install, because it tried to read a `pubspec.yaml` that doesn't
  exist next to a compiled binary. Version is now baked in at compile
  time (`--define=PDM_VERSION=...`), with the old pubspec lookup kept
  only for `dart run` during development.
- Fixed: `pdm help <command>` (and `pdm <command> --help`) silently
  falling through to "Unknown command" for a bad command or a typo,
  instead of useful help; it now suggests the closest known command.
- Fixed: a bad/unknown flag combined with `--help` produced a parse
  error instead of showing help; `-h`/`--help` is now checked before
  strict flag parsing.
- Fixed: an unrecognized command previously still built a full
  `CliContext` (config load, daemon client setup) before reporting
  "Unknown command"; it now fails fast.
- Added: `pdm completion bash|zsh` now installs the script directly into
  the system completion directory (`/usr/share/bash-completion/completions`,
  `/usr/share/zsh/site-functions`) instead of only printing it. On a
  permission error it prints the exact `sudo` command to re-run, plus a
  `--user` flag to install into the per-user completion dirs instead, and
  `--print` to keep the old print-to-stdout behavior.
- Added: the installer now installs to `/usr/bin` by default on Linux
  (previously always `~/.local/bin`, regardless of privilege). On a
  permission error it prints the exact `sudo` command to re-run, and a
  `--user` flag installs to `~/.local/bin` as before.
- Added: `<installer> uninstall` (and `<installer> uninstall --user`),
  which removes the installed binaries, the systemd `--user` service, and
  any completion scripts the installer or `pdm completion` placed.
- Added: the installer verifies a SHA-256 checksum of its embedded `pdm`/
  `pdmd` payloads before writing them to disk.
- Changed: the release workflow now runs on version tags (`v*.*.*`)
  instead of every push, and is gated behind `dart analyze`, `dart
  format --set-exit-if-changed`, and `dart test`. It also verifies the
  tag matches `pubspec.yaml` and publishes a `SHA256SUMS` file alongside
  the release binaries.
- Added: a `test/` suite covering the flag parser, help/unknown-command
  resolution, byte-size/duration parsing, checksum hashing, model JSON
  round-trips, and config loading.

## 2.0.0

- Fixed: HTTP redirects, resumed downloads no longer truncate existing
  bytes, a queue-priority field that actually affects scheduling order,
  Windows-safe home directory / config / socket / state paths, and a
  handful of other latent bugs from the 2.0.0 rewrite.
- Added scheduling: `--at` (absolute or relative time), `--every`
  (recurring downloads), `--on-startup` (deferred until the daemon next
  starts).
- Added on-complete hooks (`--on-complete`) with cross-platform built-ins
  (shutdown, restart, sleep, hibernate, lock) plus user-defined aliases in
  the config file.
- Added regex-based download rules in the config file: per-URL-pattern
  overrides for save directory, connections, proxy, speed limit, headers,
  and on-complete hook.
- Added proxy authentication (`--proxy-user`/`--proxy-pass`) and a
  no-proxy bypass list.
- Added a global speed limit shared across all concurrent downloads,
  separate from each download's own `--speed-limit`.
- Added batch import: `pdm add --file urls.txt`.
- Added duplicate detection (same URL or save path); `--allow-duplicate`
  to override.
- Added disk-space checking before a download starts.
- Added exponential backoff between retries (`--linear-retries` to
  disable).
- Added desktop notifications on completion/failure (`notifications` in
  config).
- Added `pdm history` for a persistent log of completed/failed downloads.
- Added `pdm completion bash|zsh` for shell completion scripts.
- Added `pdm daemon enable`/`disable` to auto-start the daemon at login
  (systemd user service on Linux, scheduled task on Windows, launchd
  agent on macOS).
- Queued and startup-scheduled downloads now resume automatically when
  the daemon restarts, instead of sitting idle until manually resumed.
- Multi-connection downloads can now run in the background via a detached
  daemon (`pdmd`), reachable over a Unix socket (Linux) or TCP loopback
  (Windows); foreground mode remains available via `--foreground`.
- Added 20+ flags across every command: retries, speed limiting, checksum
  verification (MD5/SHA-1/SHA-256/SHA-512, pure-Dart, no crypto dependency),
  proxy, custom headers, cookies (inline or Netscape cookie-file), basic
  auth, TLS-insecure mode, redirect limits, queue priority, and more.
- Added a config file (YAML/TOML/JSON via `pdata`), resolved from
  `PDM_CONFIG_PATH` or `~/.config/pdm/pdm.yaml`. New `pdm config dump`
  command.
- Added output theming: `default`, `rainbow`, `catppuccin`.
- Split the codebase into a strict library/CLI boundary: `lib/src/*.dart`
  has no CLI awareness; `lib/src/cli/*.dart` owns flags and formatting.
- Merged `tool/generate_payload.dart` and `tool/installer.dart` into a
  single `tool/installer.dart` with `generate` and `install` modes.
- Removed `tool/print_version.dart`; version is read from `pubspec.yaml`
  directly (via `pdata` at runtime, via `sed` in the release workflow).
- Release workflow now publishes `pdm-linux-x64.exe` and
  `pdm-windows-x64.exe`, each a self-contained installer with both `pdm`
  and `pdmd` embedded.

## 1.0.3

- fix: the installer problem is solved

## 1.0.2

- fix: the workflow is correctened 

## 1.0.1

- fix: the Github username is corretened


## 1.0.0

- Initial release

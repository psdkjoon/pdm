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

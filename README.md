# pdm

psdk download manager — library and CLI, no
third-party dependencies.

## Install

```bash
dart pub global activate pdm
```

Or grab a self-contained installer (no internet needed at install time) from
the [releases page](https://github.com/psdk/pdm/releases/latest).

## Usage

```bash
pdm add <url> [-o <output-path>] [-c <connections>]
pdm list
pdm pause <id>
pdm resume <id>
pdm watch <id>
pdm cancel <id>
pdm remove <id> [--delete-file]
```

```dart
import 'package:pdm/pdm.dart';

final manager = DownloadManager();
final task = manager.add('https://example.com/file.iso', connections: 8);
await manager.start(task.id);
```

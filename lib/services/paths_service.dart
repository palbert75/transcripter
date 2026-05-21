import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Owner of all filesystem locations Transcripter reads or writes.
/// Inject `appSupportRoot` in tests; defaults to the platform's
/// Application Support directory.
class PathsService {
  PathsService({Directory? appSupportRoot}) : _override = appSupportRoot;

  final Directory? _override;

  Future<Directory> _root() async {
    if (_override != null) return _override;
    final dir = await getApplicationSupportDirectory();
    return dir;
  }

  Future<Directory> recordingsDir() async {
    final root = await _root();
    final dir = Directory('${root.path}/recordings');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> libraryIndexDir() async {
    final root = await _root();
    final dir = Directory('${root.path}/library');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> settingsFile() async {
    final root = await _root();
    return File('${root.path}/settings.json');
  }

  Future<String> wavPathFor(String id) async {
    final dir = await recordingsDir();
    return '${dir.path}/$id.wav';
  }

  Future<String> sidecarPathFor(String id) async {
    final dir = await recordingsDir();
    return '${dir.path}/$id.json';
  }
}

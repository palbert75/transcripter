import 'dart:convert';
import 'dart:io';

import '../models/recording.dart';
import 'paths_service.dart';

/// Persists recordings as JSON sidecars next to their WAV files.
/// `list()` reads the directory and returns recordings sorted newest-first.
class LibraryService {
  LibraryService({required this.paths});

  final PathsService paths;

  Future<void> save(Recording rec) async {
    final sidecarPath = await paths.sidecarPathFor(rec.id);
    final file = File(sidecarPath);
    await file.writeAsString(jsonEncode(rec.toJson()));
  }

  Future<List<Recording>> list() async {
    final dir = await paths.recordingsDir();
    final entries = <Recording>[];
    if (!dir.existsSync()) return entries;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      try {
        final raw = await entity.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        entries.add(Recording.fromJson(json));
      } on FormatException {
        // Skip malformed sidecars; they'll be repaired on next save or
        // deleted by the user.
        continue;
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> delete(Recording rec) async {
    final wav = File(rec.wavPath);
    if (wav.existsSync()) await wav.delete();
    final sidecar = File(await paths.sidecarPathFor(rec.id));
    if (sidecar.existsSync()) await sidecar.delete();
  }
}

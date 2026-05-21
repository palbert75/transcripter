import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/recording.dart';
import 'package:transcripter/services/library_service.dart';
import 'package:transcripter/services/paths_service.dart';

void main() {
  late Directory tempRoot;
  late LibraryService lib;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('library_svc_');
    lib = LibraryService(paths: PathsService(appSupportRoot: tempRoot));
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  Recording sample(String id, {String title = 'Untitled'}) => Recording(
        id: id,
        title: title,
        createdAt: DateTime.utc(2026, 5, 21, 14, 14),
        durationSeconds: 42,
        wavPath: '/tmp/$id.wav',
        sourceName: 'BlackHole 2ch',
        transcript: '',
      );

  test('save writes a sidecar file readable by list', () async {
    await lib.save(sample('rec_a', title: 'Product sync'));
    final all = await lib.list();
    expect(all, hasLength(1));
    expect(all.first.id, 'rec_a');
    expect(all.first.title, 'Product sync');
  });

  test('list returns most-recent first', () async {
    final older = Recording(
      id: 'rec_a',
      title: 'A',
      createdAt: DateTime.utc(2026, 5, 19, 9, 0),
      durationSeconds: 10,
      wavPath: '/tmp/a.wav',
      sourceName: 'mic',
      transcript: '',
    );
    final newer = Recording(
      id: 'rec_b',
      title: 'B',
      createdAt: DateTime.utc(2026, 5, 20, 9, 0),
      durationSeconds: 10,
      wavPath: '/tmp/b.wav',
      sourceName: 'mic',
      transcript: '',
    );
    await lib.save(older);
    await lib.save(newer);
    final all = await lib.list();
    expect(all.map((r) => r.id).toList(), <String>['rec_b', 'rec_a']);
  });

  test('delete removes sidecar and wav', () async {
    final rec = sample('rec_x');
    final wavFile = File(rec.wavPath);
    await wavFile.writeAsString('fake');
    await lib.save(rec);
    await lib.delete(rec);
    final all = await lib.list();
    expect(all, isEmpty);
  });
}

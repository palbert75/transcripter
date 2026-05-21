import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/paths_service.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('transcripter_paths_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('recordingsDir is created on first access', () async {
    final svc = PathsService(appSupportRoot: tempRoot);
    final dir = await svc.recordingsDir();
    expect(dir.existsSync(), isTrue);
    expect(dir.path, endsWith('recordings'));
  });

  test('wavPathFor produces a unique path for an id', () async {
    final svc = PathsService(appSupportRoot: tempRoot);
    final p1 = await svc.wavPathFor('rec_a');
    final p2 = await svc.wavPathFor('rec_b');
    expect(p1, isNot(equals(p2)));
    expect(p1, endsWith('rec_a.wav'));
  });
}

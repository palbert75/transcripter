import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/binary_detector_service.dart';

void main() {
  late Directory tempBin;

  setUp(() async {
    tempBin = await Directory.systemTemp.createTemp('bin_detector_');
  });

  tearDown(() async {
    if (tempBin.existsSync()) await tempBin.delete(recursive: true);
  });

  test('locate returns the first candidate that exists', () async {
    final present = File('${tempBin.path}/ffmpeg');
    await present.writeAsString('#!/bin/sh\n');
    final svc = BinaryDetectorService(
      candidates: <String>[
        '/nope/ffmpeg',
        present.path,
      ],
    );
    expect(await svc.locate('ffmpeg'), present.path);
  });

  test('locate returns null when nothing matches', () async {
    final svc = BinaryDetectorService(candidates: const <String>['/nope']);
    expect(await svc.locate('ffmpeg'), isNull);
  });

  test('defaultCandidatesFor includes both Homebrew prefixes', () {
    final candidates = BinaryDetectorService.defaultCandidatesFor('ffmpeg');
    expect(candidates, contains('/opt/homebrew/bin/ffmpeg'));
    expect(candidates, contains('/usr/local/bin/ffmpeg'));
  });
}

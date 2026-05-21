import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/transcriber_service.dart';

void main() {
  test('transcribe returns whisper stdout as plain text on exit 0', () async {
    final svc = TranscriberService(
      whisperPath: '/fake/whisper-cli',
      runner: (_, _) async => ProcessResult(
        1,
        0,
        '[00:00.000 --> 00:03.000]  Hello world this is a test.\n',
        '',
      ),
    );

    final out = await svc.transcribe(
      wavPath: '/tmp/x.wav',
      modelPath: '/tmp/model.bin',
      language: 'en',
    );

    expect(out.text, contains('Hello world this is a test.'));
    expect(out.exitCode, 0);
  });

  test('transcribe throws TranscriberFailed on non-zero exit', () async {
    final svc = TranscriberService(
      whisperPath: '/fake/whisper-cli',
      runner: (_, _) async => ProcessResult(1, 2, '', 'oh no'),
    );

    expect(
      () => svc.transcribe(
        wavPath: '/tmp/x.wav',
        modelPath: '/tmp/model.bin',
        language: 'en',
      ),
      throwsA(isA<TranscriberFailed>()),
    );
  });

  test('parseTimestampedOutput strips brackets to plain prose', () {
    const raw =
        '[00:00.000 --> 00:03.000]  Hello world.\n'
        '[00:03.000 --> 00:06.500]  This is a second sentence.\n';
    final plain = TranscriberService.parseTimestampedOutput(raw);
    expect(plain, 'Hello world. This is a second sentence.');
  });
}

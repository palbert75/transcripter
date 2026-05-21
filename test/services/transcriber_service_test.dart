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

  test('parseTimestampedOutput handles whisper 1.8.x HH:MM:SS format', () {
    const raw =
        'load_backend: loaded BLAS backend from somewhere\n'
        '[00:00:00.000 --> 00:00:03.320]   Hello, this is a test.\n'
        '[00:00:03.320 --> 00:00:05.000]   Another line.\n';
    final plain = TranscriberService.parseTimestampedOutput(raw);
    expect(plain, 'Hello, this is a test. Another line.');
  });

  test('parseTimestampedOutput drops [BLANK_AUDIO] segments', () {
    const raw =
        '[00:00:00.000 --> 00:00:03.000]   [BLANK_AUDIO]\n'
        '[00:00:03.000 --> 00:00:05.000]   Real words here.\n'
        '[00:00:05.000 --> 00:00:08.000]   [MUSIC]\n';
    final plain = TranscriberService.parseTimestampedOutput(raw);
    expect(plain, 'Real words here.');
  });
}

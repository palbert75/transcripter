import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/models/recorder_state.dart';
import 'package:transcripter/services/recorder_service.dart';

class _FakeProcess implements Process {
  final int _pid = 4242;
  final Completer<int> _exit = Completer<int>();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => _pid;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  bool killCalled = false;
  ProcessSignal? lastSignal;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCalled = true;
    lastSignal = signal;
    _exit.complete(signal == ProcessSignal.sigint ? 0 : 130);
    return true;
  }
}

void main() {
  test('start emits recording state and resolves device index in ffmpeg args', () async {
    late List<String> capturedArgs;
    final fake = _FakeProcess();
    final svc = RecorderService(
      ffmpegPath: '/fake/ffmpeg',
      spawner: (executable, args) async {
        capturedArgs = args;
        return fake;
      },
    );

    final states = <RecorderState>[];
    final sub = svc.state.listen(states.add);

    await svc.start(
      source: const AudioSource(
        name: 'BlackHole 2ch',
        avFoundationIndex: 1,
        kind: AudioSourceKind.systemOutput,
      ),
      outputWavPath: '/tmp/r.wav',
    );

    // Wait a microtask to ensure the stream event is processed
    await Future<void>.delayed(Duration.zero);

    expect(svc.currentState, RecorderState.recording);
    expect(capturedArgs.contains(':1'), isTrue);
    expect(capturedArgs.contains('16000'), isTrue);
    expect(capturedArgs.last, '/tmp/r.wav');
    expect(states, contains(RecorderState.recording));
    await sub.cancel();
  });

  test('stop sends SIGINT and transitions through stopping to idle', () async {
    final fake = _FakeProcess();
    final svc = RecorderService(
      ffmpegPath: '/fake/ffmpeg',
      spawner: (_, _) async => fake,
    );

    await svc.start(
      source: const AudioSource(
        name: 'BlackHole 2ch',
        avFoundationIndex: 1,
        kind: AudioSourceKind.systemOutput,
      ),
      outputWavPath: '/tmp/r.wav',
    );

    await svc.stop();
    expect(fake.killCalled, isTrue);
    expect(fake.lastSignal, ProcessSignal.sigint);
    expect(svc.currentState, RecorderState.idle);
  });
}

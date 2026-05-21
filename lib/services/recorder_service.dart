import 'dart:async';
import 'dart:io';

import '../models/audio_source.dart';
import '../models/recorder_state.dart';

typedef ProcessSpawner = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Wraps the FFmpeg subprocess that captures audio to a WAV. Exposes the
/// current state and the elapsed time of an active recording.
class RecorderService {
  RecorderService({
    required this.ffmpegPath,
    ProcessSpawner? spawner,
  }) : _spawn = spawner ?? Process.start;

  final String ffmpegPath;
  final ProcessSpawner _spawn;

  final StreamController<RecorderState> _stateCtl =
      StreamController<RecorderState>.broadcast();
  RecorderState _state = RecorderState.idle;
  Process? _process;
  DateTime? _startedAt;

  Stream<RecorderState> get state => _stateCtl.stream;
  RecorderState get currentState => _state;
  DateTime? get startedAt => _startedAt;

  /// Begins recording. Returns once ffmpeg has been spawned.
  Future<void> start({
    required AudioSource source,
    required String outputWavPath,
  }) async {
    if (_state != RecorderState.idle) {
      throw StateError('Cannot start recorder in state $_state');
    }
    final outFile = File(outputWavPath);
    if (!outFile.parent.existsSync()) {
      await outFile.parent.create(recursive: true);
    }
    final process = await _spawn(ffmpegPath, <String>[
      '-y',
      '-f',
      'avfoundation',
      '-i',
      ':${source.avFoundationIndex}',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'pcm_s16le',
      outputWavPath,
    ]);
    _process = process;
    _startedAt = DateTime.now();
    _setState(RecorderState.recording);

    // Detach a watcher so unexpected exits flip us back to idle.
    unawaited(process.exitCode.then((_) {
      if (_state == RecorderState.recording) {
        _setState(RecorderState.idle);
        _process = null;
        _startedAt = null;
      }
    }));
  }

  /// Stops recording cleanly. SIGINT → SIGTERM → SIGKILL escalation.
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _setState(RecorderState.stopping);

    process.kill(ProcessSignal.sigint);
    try {
      await process.exitCode.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 2));
      }
    }

    _process = null;
    _startedAt = null;
    _setState(RecorderState.idle);
  }

  Duration elapsed() {
    final started = _startedAt;
    if (started == null) return Duration.zero;
    return DateTime.now().difference(started);
  }

  void dispose() {
    _process?.kill(ProcessSignal.sigint);
    _stateCtl.close();
  }

  void _setState(RecorderState s) {
    _state = s;
    _stateCtl.add(s);
  }
}

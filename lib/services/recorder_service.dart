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
  final StringBuffer _stderrLog = StringBuffer();
  StreamSubscription<List<int>>? _stderrSub;
  StreamSubscription<List<int>>? _stdoutSub;

  Stream<RecorderState> get state => _stateCtl.stream;
  RecorderState get currentState => _state;
  DateTime? get startedAt => _startedAt;

  /// The last ffmpeg stderr output (capped to the last ~8 KB). Useful for
  /// surfacing diagnostic messages when a recording is empty or fails.
  String get stderrLog => _stderrLog.toString();

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
    _stderrLog.clear();
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

    // Drain stderr so ffmpeg's diagnostic output is preserved and the pipe
    // never fills up. Cap to the last ~8 KB.
    _stderrSub = process.stderr.listen((chunk) {
      _stderrLog.write(String.fromCharCodes(chunk));
      if (_stderrLog.length > 8192) {
        final tail = _stderrLog.toString();
        _stderrLog
          ..clear()
          ..write(tail.substring(tail.length - 8192));
      }
    });
    // Drain stdout too (usually empty for our flags, but don't let it block).
    _stdoutSub = process.stdout.listen((_) {});

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

    await _stderrSub?.cancel();
    await _stdoutSub?.cancel();
    _stderrSub = null;
    _stdoutSub = null;
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

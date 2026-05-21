import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/audio_source.dart';
import '../models/recorder_state.dart';
import '../models/recording.dart';
import '../models/setup_problem.dart';
import '../services/audio_devices_service.dart';
import '../services/binary_detector_service.dart';
import '../services/library_service.dart';
import '../services/paths_service.dart';
import '../services/recorder_service.dart';
import '../services/settings_service.dart';
import '../services/transcriber_service.dart';
import '../services/wav_signal_check.dart';

/// One-stop owner of background services and reactive state.
/// Widgets subscribe via `addListener`.
class AppController extends ChangeNotifier {
  AppController({
    required this.paths,
    required this.library,
    required this.settingsSvc,
  });

  final PathsService paths;
  final LibraryService library;
  final SettingsService settingsSvc;

  AppSettings settings = AppSettings.defaults;
  String? ffmpegPath;
  String? whisperPath;

  /// Directory where downloaded Whisper models live. ~/Models on macOS.
  /// Created on demand by the downloader.
  Directory get modelsDir =>
      Directory('${Platform.environment['HOME'] ?? ''}/Models');
  List<AudioSource> sources = const <AudioSource>[];
  AudioSource? selectedSource;
  RecorderState recorderState = RecorderState.idle;
  Duration elapsed = Duration.zero;
  SetupProblem? problem;
  int recordingsCount = 0;

  RecorderService? _recorder;
  Recording? _activeRecording;
  StreamSubscription<RecorderState>? _stateSub;
  Timer? _clock;

  Future<void> bootstrap() async {
    settings = await settingsSvc.load();
    await _detectBinaries();
    await _refreshDevices();
    await _refreshLibraryCount();
    if (sources.isNotEmpty) {
      // Prefer the user's saved choice, then the first system output, then mic.
      AudioSource? preferred;
      if (settings.preferredSourceName != null) {
        preferred = sources.firstWhere(
          (s) => s.name == settings.preferredSourceName,
          orElse: () => sources.first,
        );
      } else {
        preferred = sources.firstWhere(
          (s) => s.kind == AudioSourceKind.systemOutput,
          orElse: () => sources.first,
        );
      }
      selectedSource = preferred;
    }
    notifyListeners();
  }

  Future<void> _detectBinaries() async {
    final ffmpegDetector = BinaryDetectorService(
      candidates: <String>[
        if (settings.ffmpegPathOverride != null) settings.ffmpegPathOverride!,
        ...BinaryDetectorService.defaultCandidatesFor('ffmpeg'),
      ],
    );
    final whisperDetector = BinaryDetectorService(
      candidates: <String>[
        if (settings.whisperPathOverride != null) settings.whisperPathOverride!,
        ...BinaryDetectorService.defaultCandidatesFor('whisper-cli'),
      ],
    );
    ffmpegPath = await ffmpegDetector.locate('ffmpeg');
    whisperPath = await whisperDetector.locate('whisper-cli');

    if (ffmpegPath == null) {
      problem = SetupProblem.ffmpegNotFound;
    } else if (whisperPath == null) {
      problem = SetupProblem.whisperNotFound;
    } else if (settings.modelPathOverride != null &&
        !File(settings.modelPathOverride!).existsSync()) {
      problem = SetupProblem.modelNotFound;
    } else {
      problem = null;
    }
  }

  Future<void> _refreshDevices() async {
    if (ffmpegPath == null) return;
    try {
      final svc = AudioDevicesService(ffmpegPath: ffmpegPath!);
      sources = await svc.list();
      if (sources.where((s) => s.kind == AudioSourceKind.systemOutput).isEmpty &&
          problem == null) {
        problem = SetupProblem.noSystemAudioDevice;
      }
    } on Object {
      sources = const <AudioSource>[];
    }
  }

  Future<void> _refreshLibraryCount() async {
    final all = await library.list();
    recordingsCount = all.length;
  }

  Future<void> changeSettings(AppSettings updated) async {
    settings = updated;
    await settingsSvc.save(updated);
    await _detectBinaries();
    notifyListeners();
  }

  Future<void> selectSource(AudioSource s) async {
    selectedSource = s;
    settings = settings.copyWith(preferredSourceName: s.name);
    await settingsSvc.save(settings);
    notifyListeners();
  }

  Future<Recording?> startRecording() async {
    if (problem != null || ffmpegPath == null || selectedSource == null) return null;
    final id = 'rec_${DateTime.now().millisecondsSinceEpoch}';
    final wavPath = await paths.wavPathFor(id);
    _recorder = RecorderService(ffmpegPath: ffmpegPath!);
    await _recorder!.start(source: selectedSource!, outputWavPath: wavPath);
    _activeRecording = Recording(
      id: id,
      title: '',
      createdAt: DateTime.now().toUtc(),
      durationSeconds: 0,
      wavPath: wavPath,
      sourceName: selectedSource!.name,
      transcript: '',
    );
    _stateSub = _recorder!.state.listen((s) {
      recorderState = s;
      notifyListeners();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed = _recorder?.elapsed() ?? Duration.zero;
      notifyListeners();
    });
    recorderState = RecorderState.recording;
    elapsed = Duration.zero;
    notifyListeners();
    return _activeRecording;
  }

  /// Peak amplitude (0..32767) of the most recent recording, or null if not
  /// yet measured. Below [WavSignalReport.silentThreshold] indicates a
  /// silent capture (likely a routing/permission problem).
  int? lastRecordingPeak;

  /// Last ffmpeg stderr (truncated) from the most recent recording.
  String lastRecorderStderr = '';

  Future<Recording?> stopRecording() async {
    final rec = _recorder;
    final pending = _activeRecording;
    if (rec == null || pending == null) return null;
    final dur = rec.elapsed();
    await rec.stop();
    lastRecorderStderr = rec.stderrLog;
    _clock?.cancel();
    await _stateSub?.cancel();
    _stateSub = null;
    _recorder = null;
    elapsed = Duration.zero;
    recorderState = RecorderState.idle;

    final completed = pending.copyWith(durationSeconds: dur.inSeconds);
    await library.save(completed);
    await _refreshLibraryCount();

    final report = await inspectWav(completed.wavPath);
    lastRecordingPeak = report?.maxAbs;

    notifyListeners();
    _activeRecording = null;
    return completed;
  }

  Future<Recording> transcribe(Recording rec) async {
    if (whisperPath == null) {
      throw const TranscribeUnavailable('whisper-cli is not configured');
    }
    final modelPath = settings.modelPathOverride ??
        '${Platform.environment['HOME'] ?? ''}/Models/ggml-base.en.bin';
    if (!File(modelPath).existsSync()) {
      problem = SetupProblem.modelNotFound;
      // Defer the notify to the next microtask so listeners that call
      // setState are not invoked while the caller is still building.
      scheduleMicrotask(notifyListeners);
      throw TranscribeUnavailable('Speech model not found at $modelPath');
    }
    final svc = TranscriberService(whisperPath: whisperPath!);
    final result = await svc.transcribe(
      wavPath: rec.wavPath,
      modelPath: modelPath,
      language: settings.language,
    );
    final autoTitle =
        rec.title.isEmpty ? Recording.deriveTitle(result.text) : rec.title;
    final updated = rec.copyWith(transcript: result.text, title: autoTitle);
    await library.save(updated);
    return updated;
  }

  Future<void> updateRecording(Recording rec) async {
    await library.save(rec);
    notifyListeners();
  }

  Future<void> deleteRecording(Recording rec) async {
    await library.delete(rec);
    await _refreshLibraryCount();
    notifyListeners();
  }

  Future<List<Recording>> listRecordings() => library.list();

  @override
  void dispose() {
    _stateSub?.cancel();
    _clock?.cancel();
    _recorder?.dispose();
    super.dispose();
  }
}

/// Thrown by [AppController.transcribe] when prerequisites for transcription
/// (whisper-cli binary, model file) are missing. UI catches this to show a
/// user-facing message instead of crashing.
class TranscribeUnavailable implements Exception {
  const TranscribeUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

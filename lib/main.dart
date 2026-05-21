import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const TranscripterApp());
}

class TranscripterApp extends StatelessWidget {
  const TranscripterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transcripter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1f6f64),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const RecorderPage(),
    );
  }
}

enum RecorderState { idle, listing, recording, stopping, transcribing }

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final _ffmpegPathController = TextEditingController(
    text: '/opt/homebrew/bin/ffmpeg',
  );
  final _deviceController = TextEditingController(text: 'BlackHole 2ch');
  final _outputController = TextEditingController();
  final _whisperPathController = TextEditingController(
    text: '/opt/homebrew/bin/whisper-cli',
  );
  final _whisperModelController = TextEditingController();
  final _languageController = TextEditingController(text: 'en');

  RecorderState _state = RecorderState.idle;
  Process? _recordingProcess;
  DateTime? _recordingStartedAt;
  Timer? _clock;
  String _elapsed = '00:00';
  String _devicesOutput = '';
  String _transcriptOutput = '';
  final List<String> _logLines = <String>[];

  bool get _isBusy =>
      _state == RecorderState.listing || _state == RecorderState.transcribing;

  bool get _isRecording =>
      _state == RecorderState.recording || _state == RecorderState.stopping;

  @override
  void initState() {
    super.initState();
    _outputController.text = _defaultOutputPath();
    _whisperModelController.text = _defaultWhisperModelPath();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _recordingProcess?.kill(ProcessSignal.sigint);
    _ffmpegPathController.dispose();
    _deviceController.dispose();
    _outputController.dispose();
    _whisperPathController.dispose();
    _whisperModelController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  String _defaultOutputPath() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceFirst(RegExp(r'\.\d+$'), '');
    return '$home/Documents/transcripter-$timestamp.wav';
  }

  String _defaultWhisperModelPath() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return '$home/Models/ggml-base.en.bin';
  }

  Future<void> _listDevices() async {
    if (_isRecording) return;

    setState(() {
      _state = RecorderState.listing;
      _devicesOutput = '';
      _appendLog('Listing AVFoundation devices...');
    });

    try {
      final result = await Process.run(
        _ffmpegPathController.text.trim(),
        const ['-f', 'avfoundation', '-list_devices', 'true', '-i', ''],
      );

      setState(() {
        _devicesOutput = [
          if (result.stdout.toString().trim().isNotEmpty) result.stdout,
          if (result.stderr.toString().trim().isNotEmpty) result.stderr,
        ].join('\n').trim();
        _appendLog('Device listing finished.');
      });
    } on Object catch (error) {
      setState(() {
        _devicesOutput = error.toString();
        _appendLog('Device listing failed: $error');
      });
    } finally {
      if (mounted) {
        setState(() => _state = RecorderState.idle);
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isBusy || _isRecording) return;

    final ffmpegPath = _ffmpegPathController.text.trim();
    final device = _deviceController.text.trim();
    final outputPath = _outputController.text.trim();

    if (ffmpegPath.isEmpty || device.isEmpty || outputPath.isEmpty) {
      _log('Fill in ffmpeg path, input device, and output WAV path.');
      return;
    }

    try {
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);

      final process = await Process.start(ffmpegPath, [
        '-y',
        '-f',
        'avfoundation',
        '-i',
        ':$device',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'pcm_s16le',
        outputPath,
      ]);

      _recordingProcess = process;
      _recordingStartedAt = DateTime.now();
      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        final startedAt = _recordingStartedAt;
        if (startedAt == null || !mounted) return;
        final duration = DateTime.now().difference(startedAt);
        setState(() {
          _elapsed = _formatDuration(duration);
        });
      });

      _streamProcessOutput(process);

      setState(() {
        _state = RecorderState.recording;
        _elapsed = '00:00';
        _appendLog('Recording started: $outputPath');
      });

      unawaited(_watchRecordingExit(process));
    } on Object catch (error) {
      setState(() {
        _state = RecorderState.idle;
        _appendLog('Could not start recording: $error');
      });
    }
  }

  void _streamProcessOutput(Process process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (mounted) setState(() => _appendLog(line));
        });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (mounted) setState(() => _appendLog(line));
        });
  }

  Future<void> _watchRecordingExit(Process process) async {
    final exitCode = await process.exitCode;
    _clearRecordingState(
      process,
      'Recording stopped. ffmpeg exit code: $exitCode',
    );
  }

  Future<void> _stopRecording() async {
    final process = _recordingProcess;
    if (process == null) return;

    setState(() {
      _state = RecorderState.stopping;
      _appendLog('Stopping recording...');
    });

    try {
      final interrupted = process.kill(ProcessSignal.sigint);
      _log('Sent SIGINT to ffmpeg: $interrupted');
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 4),
      );
      _clearRecordingState(
        process,
        'Recording stopped. ffmpeg exit code: $exitCode',
      );
      return;
    } on TimeoutException {
      _log('ffmpeg did not exit after SIGINT; sending SIGTERM.');
    } on Object catch (error) {
      _log('Could not stop ffmpeg with SIGINT: $error');
    }

    try {
      final terminated = process.kill(ProcessSignal.sigterm);
      _log('Sent SIGTERM to ffmpeg: $terminated');
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 3),
      );
      _clearRecordingState(
        process,
        'Recording stopped. ffmpeg exit code: $exitCode',
      );
      return;
    } on TimeoutException {
      _log('ffmpeg did not exit after SIGTERM; sending SIGKILL.');
    } on Object catch (error) {
      _log('Could not stop ffmpeg with SIGTERM: $error');
    }

    try {
      final killed = process.kill(ProcessSignal.sigkill);
      _log('Sent SIGKILL to ffmpeg: $killed');
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 2),
      );
      _clearRecordingState(
        process,
        'Recording killed. ffmpeg exit code: $exitCode',
      );
    } on TimeoutException {
      _clearRecordingState(
        process,
        'ffmpeg did not report exit after SIGKILL; reset recorder UI.',
      );
    } on Object catch (error) {
      _clearRecordingState(
        process,
        'Could not confirm ffmpeg exit after SIGKILL: $error',
      );
    }
  }

  Future<void> _transcribe() async {
    if (_isRecording || _isBusy) return;

    final whisperPath = _whisperPathController.text.trim();
    final wavPath = _outputController.text.trim();
    final modelPath = _whisperModelController.text.trim();
    final language = _languageController.text.trim();

    if (whisperPath.isEmpty || modelPath.isEmpty || wavPath.isEmpty) {
      _log(
        'Fill in whisper.cpp binary, model file, and WAV path before transcribing.',
      );
      return;
    }

    if (!File(wavPath).existsSync()) {
      _log('WAV file does not exist yet: $wavPath');
      return;
    }

    if (!File(modelPath).existsSync()) {
      _log('whisper.cpp model file does not exist: $modelPath');
      return;
    }

    setState(() {
      _state = RecorderState.transcribing;
      _transcriptOutput = '';
      _appendLog('Starting whisper.cpp transcription...');
    });

    try {
      final args = <String>[
        '-m',
        modelPath,
        '-f',
        wavPath,
        '-np',
        if (language.isNotEmpty) ...['-l', language],
      ];
      final result = await Process.run(whisperPath, args);
      final output = [
        if (result.stdout.toString().trim().isNotEmpty) result.stdout,
        if (result.stderr.toString().trim().isNotEmpty) result.stderr,
      ].join('\n').trim();

      setState(() {
        _transcriptOutput = output;
        _appendLog('Transcription finished. Exit code: ${result.exitCode}');
      });
    } on Object catch (error) {
      setState(() {
        _transcriptOutput = error.toString();
        _appendLog('Transcription failed: $error');
      });
    } finally {
      if (mounted) {
        setState(() => _state = RecorderState.idle);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _appendLog(String line) {
    if (line.trim().isEmpty) return;
    _logLines.add(line);
    if (_logLines.length > 220) {
      _logLines.removeRange(0, _logLines.length - 220);
    }
  }

  void _log(String line) {
    if (!mounted) {
      _appendLog(line);
      return;
    }
    setState(() => _appendLog(line));
  }

  void _clearRecordingState(Process process, String logLine) {
    if (!mounted || _recordingProcess != process) return;

    _clock?.cancel();
    setState(() {
      _state = RecorderState.idle;
      _recordingProcess = null;
      _recordingStartedAt = null;
      _appendLog(logLine);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7f4),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            final controls = _ControlPanel(
              state: _state,
              elapsed: _elapsed,
              ffmpegPathController: _ffmpegPathController,
              deviceController: _deviceController,
              outputController: _outputController,
              whisperPathController: _whisperPathController,
              whisperModelController: _whisperModelController,
              languageController: _languageController,
              onListDevices: _listDevices,
              onStart: _startRecording,
              onStop: _stopRecording,
              onTranscribe: _transcribe,
            );
            final output = _OutputPanel(
              devicesOutput: _devicesOutput,
              transcriptOutput: _transcriptOutput,
              logLines: _logLines,
            );

            return Padding(
              padding: const EdgeInsets.all(20),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: controls),
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: output),
                      ],
                    )
                  : ListView(
                      children: [
                        SizedBox(height: 560, child: controls),
                        const SizedBox(height: 16),
                        SizedBox(height: 560, child: output),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.state,
    required this.elapsed,
    required this.ffmpegPathController,
    required this.deviceController,
    required this.outputController,
    required this.whisperPathController,
    required this.whisperModelController,
    required this.languageController,
    required this.onListDevices,
    required this.onStart,
    required this.onStop,
    required this.onTranscribe,
  });

  final RecorderState state;
  final String elapsed;
  final TextEditingController ffmpegPathController;
  final TextEditingController deviceController;
  final TextEditingController outputController;
  final TextEditingController whisperPathController;
  final TextEditingController whisperModelController;
  final TextEditingController languageController;
  final VoidCallback onListDevices;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onTranscribe;

  @override
  Widget build(BuildContext context) {
    final isRecording =
        state == RecorderState.recording || state == RecorderState.stopping;
    final canStop = state == RecorderState.recording;
    final busy =
        state == RecorderState.listing ||
        state == RecorderState.stopping ||
        state == RecorderState.transcribing;

    return _Surface(
      child: ListView(
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transcripter',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      _statusText(state),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _RecordingBadge(isRecording: isRecording, elapsed: elapsed),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recorder', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: ffmpegPathController,
            decoration: const InputDecoration(
              labelText: 'ffmpeg path',
              prefixIcon: Icon(Icons.terminal),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: deviceController,
            decoration: const InputDecoration(
              labelText: 'AVFoundation input device',
              prefixIcon: Icon(Icons.settings_input_component),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: outputController,
            decoration: const InputDecoration(
              labelText: 'Output WAV file',
              prefixIcon: Icon(Icons.audio_file),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: busy || isRecording ? null : onListDevices,
                icon: const Icon(Icons.list),
                label: const Text('List Devices'),
              ),
              FilledButton.icon(
                onPressed: busy || isRecording ? null : onStart,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Record'),
              ),
              OutlinedButton.icon(
                onPressed: canStop ? onStop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Transcription', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: whisperPathController,
            decoration: const InputDecoration(
              labelText: 'whisper.cpp binary',
              prefixIcon: Icon(Icons.subtitles),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: whisperModelController,
                  decoration: const InputDecoration(
                    labelText: 'Model file',
                    prefixIcon: Icon(Icons.memory),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: languageController,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    prefixIcon: Icon(Icons.language),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || isRecording ? null : onTranscribe,
            icon: const Icon(Icons.article),
            label: const Text('Transcribe WAV'),
          ),
        ],
      ),
    );
  }

  String _statusText(RecorderState state) {
    return switch (state) {
      RecorderState.idle => 'Ready to record routed macOS system audio.',
      RecorderState.listing => 'Reading audio devices from ffmpeg.',
      RecorderState.recording => 'Recording 16 kHz mono WAV.',
      RecorderState.stopping => 'Stopping ffmpeg and finalizing WAV.',
      RecorderState.transcribing => 'Running whisper.cpp locally.',
    };
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({
    required this.devicesOutput,
    required this.transcriptOutput,
    required this.logLines,
  });

  final String devicesOutput;
  final String transcriptOutput;
  final List<String> logLines;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.speaker), text: 'Devices'),
                Tab(icon: Icon(Icons.notes), text: 'Transcript'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Log'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _MonospaceOutput(
                    text: devicesOutput.isEmpty
                        ? 'No devices listed.'
                        : devicesOutput,
                  ),
                  _MonospaceOutput(
                    text: transcriptOutput.isEmpty
                        ? 'No whisper.cpp transcript yet.'
                        : transcriptOutput,
                  ),
                  _MonospaceOutput(
                    text: logLines.isEmpty
                        ? 'No events yet.'
                        : logLines.join('\n'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge({required this.isRecording, required this.elapsed});

  final bool isRecording;
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final color = isRecording
        ? const Color(0xffb3261e)
        : const Color(0xff56615c);
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRecording
                ? Icons.fiber_manual_record
                : Icons.pause_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            elapsed,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffd8ded8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _MonospaceOutput extends StatefulWidget {
  const _MonospaceOutput({required this.text});

  final String text;

  @override
  State<_MonospaceOutput> createState() => _MonospaceOutputState();
}

class _MonospaceOutputState extends State<_MonospaceOutput> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff101412),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            widget.text,
            style: const TextStyle(
              color: Color(0xffe7eee8),
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

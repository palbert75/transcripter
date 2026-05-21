import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class TranscriptionResult {
  const TranscriptionResult({required this.text, required this.exitCode});

  final String text;
  final int exitCode;
}

class TranscriberFailed implements Exception {
  TranscriberFailed(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;

  @override
  String toString() =>
      'whisper-cli failed with exit code $exitCode:\n$stderr';
}

/// Runs whisper.cpp (`whisper-cli`) on a WAV file and returns the transcript.
class TranscriberService {
  TranscriberService({
    required this.whisperPath,
    ProcessRunner? runner,
  }) : _run = runner ?? Process.run;

  final String whisperPath;
  final ProcessRunner _run;

  Future<TranscriptionResult> transcribe({
    required String wavPath,
    required String modelPath,
    required String language,
  }) async {
    final args = <String>[
      '-m',
      modelPath,
      '-f',
      wavPath,
      '-np', // no progress prints — keeps stdout transcript-only
      if (language.isNotEmpty) ...<String>['-l', language],
    ];
    final result = await _run(whisperPath, args);
    if (result.exitCode != 0) {
      throw TranscriberFailed(
        result.exitCode,
        result.stderr?.toString() ?? '',
      );
    }
    final raw = result.stdout?.toString() ?? '';
    return TranscriptionResult(
      text: parseTimestampedOutput(raw),
      exitCode: result.exitCode,
    );
  }

  /// whisper-cli (without `-otxt`) prints lines like
  ///   `[00:00.000 --> 00:03.000]  Hello.`
  /// Strip the timestamps and join into prose.
  static String parseTimestampedOutput(String raw) {
    final lineRe = RegExp(r'^\[\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}\.\d{3}\]\s*(.*)$');
    final out = <String>[];
    for (final line in raw.split('\n')) {
      final m = lineRe.firstMatch(line.trim());
      if (m != null) {
        final segment = m.group(1)!.trim();
        if (segment.isNotEmpty) out.add(segment);
      }
    }
    return out.join(' ');
  }
}

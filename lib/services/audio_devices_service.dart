import 'dart:io';

import '../models/audio_source.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Enumerates AVFoundation audio capture devices by parsing
/// `ffmpeg -f avfoundation -list_devices true -i ""` output.
class AudioDevicesService {
  AudioDevicesService({
    required this.ffmpegPath,
    ProcessRunner? runner,
  }) : _run = runner ?? Process.run;

  final String ffmpegPath;
  final ProcessRunner _run;

  Future<List<AudioSource>> list() async {
    // ffmpeg prints to stderr and exits non-zero — both are expected.
    final result = await _run(ffmpegPath, const <String>[
      '-f',
      'avfoundation',
      '-list_devices',
      'true',
      '-i',
      '',
    ]);
    final combined =
        '${result.stdout?.toString() ?? ''}\n${result.stderr?.toString() ?? ''}';
    return parseList(combined);
  }

  /// Pure parser, exposed for unit testing.
  static List<AudioSource> parseList(String output) {
    final lines = output.split('\n');
    bool inAudioBlock = false;
    final entries = <AudioSource>[];
    final entryPattern = RegExp(r'\[\d+\]\s+(.+)$');

    for (final raw in lines) {
      final line = raw.trim();
      if (line.contains('AVFoundation audio devices')) {
        inAudioBlock = true;
        continue;
      }
      if (line.contains('AVFoundation video devices')) {
        inAudioBlock = false;
        continue;
      }
      if (!inAudioBlock) continue;

      // Lines look like:
      // [AVFoundation indev @ 0x…] [1] BlackHole 2ch
      final bracketIdx = line.indexOf('] [');
      if (bracketIdx < 0) continue;
      final tail = line.substring(bracketIdx + 2); // "[1] BlackHole 2ch"
      final match = entryPattern.firstMatch(tail);
      if (match == null) continue;
      final indexStr = RegExp(r'\[(\d+)\]').firstMatch(tail)?.group(1);
      if (indexStr == null) continue;
      final name = match.group(1)!.trim();
      entries.add(AudioSource(
        name: name,
        avFoundationIndex: int.parse(indexStr),
        kind: AudioSource.classify(name),
      ));
    }

    return entries;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/services/audio_devices_service.dart';

const String _sampleOutput = '''
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
[AVFoundation indev @ 0xa17400140] AVFoundation video devices:
[AVFoundation indev @ 0xa17400140] [0] FaceTime HD Camera
[AVFoundation indev @ 0xa17400140] [1] papp's iPhone 16 Camera
[AVFoundation indev @ 0xa17400140] AVFoundation audio devices:
[AVFoundation indev @ 0xa17400140] [0] CalDigit Thunderbolt 3 Audio
[AVFoundation indev @ 0xa17400140] [1] BlackHole 2ch
[AVFoundation indev @ 0xa17400140] [2] MacBook Pro Microphone
[AVFoundation indev @ 0xa17400140] [3] HyperX Quadcast
[in#0 @ 0xa17400000] Error opening input: Input/output error
''';

void main() {
  test('parses audio devices, ignores video block', () {
    final devices = AudioDevicesService.parseList(_sampleOutput);
    expect(devices, hasLength(4));
    expect(devices[1].name, 'BlackHole 2ch');
    expect(devices[1].avFoundationIndex, 1);
    expect(devices[1].kind, AudioSourceKind.systemOutput);
  });

  test('classifies microphones correctly', () {
    final devices = AudioDevicesService.parseList(_sampleOutput);
    expect(devices[2].kind, AudioSourceKind.microphone);
  });

  test('returns empty list when no audio block present', () {
    final devices = AudioDevicesService.parseList(
      '[AVFoundation indev @ 0x0] AVFoundation video devices:\n'
      '[AVFoundation indev @ 0x0] [0] FaceTime HD Camera\n',
    );
    expect(devices, isEmpty);
  });
}

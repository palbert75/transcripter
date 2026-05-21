import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/audio_source.dart';

void main() {
  test('AudioSource.system identifies BlackHole-like inputs by name', () {
    const src = AudioSource(
      name: 'BlackHole 2ch',
      avFoundationIndex: 1,
      kind: AudioSourceKind.systemOutput,
    );
    expect(src.kind, AudioSourceKind.systemOutput);
    expect(src.displayName, 'BlackHole 2ch');
  });

  test('AudioSource equality is value-based', () {
    const a = AudioSource(
      name: 'MacBook Pro Microphone',
      avFoundationIndex: 2,
      kind: AudioSourceKind.microphone,
    );
    const b = AudioSource(
      name: 'MacBook Pro Microphone',
      avFoundationIndex: 2,
      kind: AudioSourceKind.microphone,
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}

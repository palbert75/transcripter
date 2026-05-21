import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/recording.dart';

void main() {
  test('Recording serializes to and from JSON', () {
    final r = Recording(
      id: 'rec_abc',
      title: 'Product sync',
      createdAt: DateTime.parse('2026-05-21T14:14:00.000Z'),
      durationSeconds: 42,
      wavPath: '/tmp/rec_abc.wav',
      sourceName: 'BlackHole 2ch',
      transcript: 'So the key insight here…',
    );

    final json = r.toJson();
    final round = Recording.fromJson(json);

    expect(round, equals(r));
  });

  test('Recording.untitled derives a title from first sentence of transcript', () {
    final t = Recording.deriveTitle(
      'So the key insight here is that BlackHole gives us a virtual cable. '
      'Then the next step is to wire it up.',
    );
    expect(t, 'So the key insight here is that BlackHole gives us a virtual cable.');
  });

  test('Recording.deriveTitle truncates a long single-sentence transcript', () {
    final long = 'a' * 200;
    final t = Recording.deriveTitle(long);
    expect(t.length, lessThanOrEqualTo(63)); // 60 + "…"
    expect(t, endsWith('…'));
  });

  test('Recording.deriveTitle returns empty when transcript is empty', () {
    expect(Recording.deriveTitle(''), '');
    expect(Recording.deriveTitle('   '), '');
  });
}

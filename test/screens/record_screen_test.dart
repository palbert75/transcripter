import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/screens/record/record_screen.dart';

void main() {
  testWidgets('RecordScreen shows brand, source pill, timer at idle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const RecordScreen.preview(
          source: AudioSource(
            name: 'BlackHole 2ch',
            avFoundationIndex: 1,
            kind: AudioSourceKind.systemOutput,
          ),
        ),
      ),
    );

    expect(find.text('Transcripter'), findsOneWidget);
    expect(find.textContaining('BlackHole 2ch'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Tap to record'), findsOneWidget);
  });
}

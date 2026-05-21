import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/screens/record/source_pill.dart';

void main() {
  testWidgets('SourcePill shows device name and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SourcePill(
              source: const AudioSource(
                name: 'BlackHole 2ch',
                avFoundationIndex: 1,
                kind: AudioSourceKind.systemOutput,
              ),
              enabled: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('BlackHole 2ch'), findsOneWidget);
    await tester.tap(find.byType(SourcePill));
    expect(taps, 1);
  });

  testWidgets('SourcePill does not invoke onTap when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SourcePill(
              source: const AudioSource(
                name: 'mic',
                avFoundationIndex: 0,
                kind: AudioSourceKind.microphone,
              ),
              enabled: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SourcePill));
    expect(taps, 0);
  });
}

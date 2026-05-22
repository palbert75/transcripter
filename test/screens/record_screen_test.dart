import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/models/recorder_state.dart';
import 'package:transcripter/models/setup_problem.dart';
import 'package:transcripter/screens/record/record_screen.dart';

void main() {
  const source = AudioSource(
    name: 'BlackHole 2ch',
    avFoundationIndex: 1,
    kind: AudioSourceKind.systemOutput,
  );

  testWidgets('RecordScreen shows brand, source pill, timer at idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const RecordScreen.preview(source: source),
      ),
    );

    expect(find.text('Transcripter'), findsOneWidget);
    expect(find.textContaining('BlackHole 2ch'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Tap to record'), findsOneWidget);
  });

  testWidgets(
    'RecordScreen does not overflow when controls are height constrained',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: RecordScreen(
            source: source,
            allSources: const <AudioSource>[],
            state: RecorderState.idle,
            elapsed: Duration.zero,
            problem: SetupProblem.ffmpegNotFound,
            recordingsCount: 0,
            onStart: () {},
            onStop: () {},
            onPickSource: (_) async {},
            onOpenLibrary: () {},
            onOpenSettings: () {},
            onResolveProblem: (_) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('FFmpeg not found'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    },
  );
}

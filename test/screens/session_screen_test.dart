import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/recording.dart';
import 'package:transcripter/screens/session/session_screen.dart';

void main() {
  testWidgets('SessionScreen shows title and transcript when ready', (
    tester,
  ) async {
    final rec = Recording(
      id: 'r1',
      title: 'Product sync',
      createdAt: DateTime(2026, 5, 21, 14, 14),
      durationSeconds: 42,
      wavPath: '/tmp/r1.wav',
      sourceName: 'BlackHole 2ch',
      transcript: 'Hello world. This is a test.',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SessionScreen(
          recording: rec,
          isTranscribing: false,
          onBack: () {},
          onDelete: () {},
          onExport: () {},
          onCopy: () {},
          onTitleChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Product sync'), findsOneWidget);
    expect(find.textContaining('Hello world'), findsOneWidget);
  });

  testWidgets('SessionScreen shows Untitled when transcribing and no title', (
    tester,
  ) async {
    final rec = Recording(
      id: 'r1',
      title: '',
      createdAt: DateTime(2026, 5, 21, 14, 14),
      durationSeconds: 42,
      wavPath: '/tmp/r1.wav',
      sourceName: 'BlackHole 2ch',
      transcript: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SessionScreen(
          recording: rec,
          isTranscribing: true,
          onBack: () {},
          onDelete: () {},
          onExport: () {},
          onCopy: () {},
          onTitleChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Untitled recording'), findsOneWidget);
  });

  testWidgets('SessionScreen header copy button calls onCopy', (tester) async {
    final rec = Recording(
      id: 'r1',
      title: 'Product sync',
      createdAt: DateTime(2026, 5, 21, 14, 14),
      durationSeconds: 42,
      wavPath: '/tmp/r1.wav',
      sourceName: 'BlackHole 2ch',
      transcript: 'Hello world. This is a test.',
    );
    var copied = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SessionScreen(
          recording: rec,
          isTranscribing: false,
          onBack: () {},
          onDelete: () {},
          onExport: () {},
          onCopy: () => copied = true,
          onTitleChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Copy'));

    expect(copied, isTrue);
  });
}

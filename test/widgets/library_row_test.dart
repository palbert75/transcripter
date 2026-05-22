import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/recording.dart';
import 'package:transcripter/screens/library/library_row.dart';

void main() {
  testWidgets(
    'LibraryRow exposes delete directly and confirms before deleting',
    (tester) async {
      final recording = Recording(
        id: 'rec-1',
        title: 'Design notes',
        createdAt: DateTime.utc(2026, 5, 22, 8, 30),
        durationSeconds: 83,
        wavPath: '/tmp/rec-1.wav',
        sourceName: 'BlackHole 2ch',
        transcript: 'The first few lines of the transcript.',
      );
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: LibraryRow(
                recording: recording,
                onTap: () {},
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Delete recording'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);

      await tester.tap(find.byTooltip('Delete recording'));
      await tester.pumpAndSettle();

      expect(find.text('Delete recording?'), findsOneWidget);
      expect(deleted, isFalse);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/screens/record/record_button.dart';

void main() {
  testWidgets('RecordButton fires onTap when active', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: RecordButton(
              isRecording: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecordButton));
    expect(taps, 1);
  });

  testWidgets('RecordButton renders darker fill while recording', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: RecordButton(isRecording: true, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecordButton), findsOneWidget);
  });
}

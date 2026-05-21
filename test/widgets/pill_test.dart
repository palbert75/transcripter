import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/widgets/pill.dart';

void main() {
  testWidgets('Pill shows label and dot, is tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Pill(
            label: 'System audio',
            dotColor: ColorTokens.accent,
            trailing: const Icon(Icons.arrow_drop_down, size: 12),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('System audio'), findsOneWidget);
    await tester.tap(find.byType(Pill));
    expect(taps, 1);
  });
}

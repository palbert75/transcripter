import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/widgets/soft_card.dart';

void main() {
  testWidgets('SoftCard renders child on paper surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SoftCard(child: Text('hello')),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    final container = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SoftCard),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, ColorTokens.paper);
  });
}

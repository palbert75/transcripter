import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/setup_problem.dart';
import 'package:transcripter/widgets/error_banner.dart';

void main() {
  testWidgets('ErrorBanner shows problem copy and fires action', (tester) async {
    var actionTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ErrorBanner(
            problem: SetupProblem.microphonePermissionDenied,
            onAction: () => actionTaps++,
          ),
        ),
      ),
    );

    expect(find.text(SetupProblem.microphonePermissionDenied.title), findsOneWidget);
    expect(find.text(SetupProblem.microphonePermissionDenied.actionLabel), findsOneWidget);

    await tester.tap(find.text(SetupProblem.microphonePermissionDenied.actionLabel));
    expect(actionTaps, 1);
  });
}

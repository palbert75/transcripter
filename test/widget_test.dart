import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcripter/main.dart';

void main() {
  testWidgets('shows recorder controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TranscripterApp());

    expect(find.text('Transcripter'), findsOneWidget);
    expect(find.text('List Devices'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Transcribe WAV'), findsOneWidget);
    expect(find.text('whisper.cpp binary'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
  });
}

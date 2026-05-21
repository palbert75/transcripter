import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';

void main() {
  test('ColorTokens are warm and never pure black', () {
    expect(ColorTokens.ink, isNot(equals(Colors.black)));
    expect(ColorTokens.ink.r, greaterThan(0.1));
  });

  test('AppTheme exposes a material 3 light theme using cream surface', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, ColorTokens.cream);
  });
}

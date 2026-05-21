import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 96×96 circular button. Terracotta gradient when idle, dark ink when
/// recording (signals "press to stop"). Outer halo intensifies on active.
class RecordButton extends StatelessWidget {
  const RecordButton({
    required this.isRecording,
    required this.onTap,
    this.disabled = false,
    super.key,
  });

  final bool isRecording;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final fillGradient = isRecording
        ? const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: <Color>[Color(0xFF3A2E24), ColorTokens.ink],
          )
        : const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: <Color>[Color(0xFFEE8A5A), ColorTokens.accentDeep],
          );

    final shadowColor = isRecording
        ? const Color(0x59281E14)
        : const Color(0x52C0432A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: disabled ? null : fillGradient,
          color: disabled ? ColorTokens.inkFaint : null,
          boxShadow: <BoxShadow>[
            if (!disabled)
              BoxShadow(
                color: shadowColor,
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
          ],
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xF2FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

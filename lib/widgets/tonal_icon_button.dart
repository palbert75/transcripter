import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';

/// 28×28 hoverable icon button used in screen headers.
class TonalIconButton extends StatelessWidget {
  const TonalIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onPressed,
          hoverColor: const Color(0x0A000000),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: onPressed == null
                  ? ColorTokens.inkFaint
                  : ColorTokens.inkSoft,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

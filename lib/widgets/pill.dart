import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';

/// Rounded pill used for the source picker trigger and live-state badges.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    this.dotColor,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String label;
  final Color? dotColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (dotColor != null) ...<Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Spacing.sm),
      ],
      Text(label, style: const TextStyle(fontSize: 11, color: ColorTokens.ink)),
      if (trailing != null) ...<Widget>[
        const SizedBox(width: Spacing.sm),
        DefaultTextStyle.merge(
          style: const TextStyle(color: ColorTokens.inkFaint, fontSize: 9),
          child: trailing!,
        ),
      ],
    ];

    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: ColorTokens.paper,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F3C2814),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: 6,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

    if (onTap == null) return pill;

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.pill),
      onTap: onTap,
      child: pill,
    );
  }
}

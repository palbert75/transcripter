import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';

/// White card with a warm shadow. The canonical container for content
/// resting on the cream window background.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.radius = Radii.lg,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColorTokens.paper,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F3C2814), // rgba(60,40,20,.06)
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';
import '../models/setup_problem.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.problem,
    required this.onAction,
    super.key,
  });

  final SetupProblem problem;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF0E8),
        border: Border.all(color: const Color(0xFFF4C8B1)),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded,
                color: ColorTokens.accentDeep, size: 18),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  problem.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  problem.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ColorTokens.inkSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onAction,
                  child: Text(
                    problem.actionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ColorTokens.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

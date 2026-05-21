import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';

class SessionToolbar extends StatelessWidget {
  const SessionToolbar({
    required this.onDelete,
    required this.onExport,
    required this.onCopy,
    required this.onDone,
    super.key,
  });

  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      color: ColorTokens.cream2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _btn(label: 'Delete', tertiary: true, onTap: onDelete),
          const SizedBox(width: Spacing.sm),
          _btn(label: 'Export…', onTap: onExport),
          const SizedBox(width: Spacing.sm),
          _btn(label: 'Copy text', onTap: onCopy),
          const SizedBox(width: Spacing.sm),
          _btn(label: 'Done', primary: true, onTap: onDone),
        ],
      ),
    );
  }

  Widget _btn({
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool tertiary = false,
  }) {
    final Color bg = primary
        ? ColorTokens.ink
        : tertiary
            ? Colors.transparent
            : ColorTokens.paper;
    final Color fg = primary
        ? ColorTokens.cream
        : tertiary
            ? ColorTokens.inkSoft
            : ColorTokens.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: tertiary || primary
              ? null
              : Border.all(color: ColorTokens.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
        ),
      ),
    );
  }
}

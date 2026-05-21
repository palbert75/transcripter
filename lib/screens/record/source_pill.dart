import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/audio_source.dart';
import '../../widgets/pill.dart';

class SourcePill extends StatelessWidget {
  const SourcePill({
    required this.source,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final AudioSource source;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = source.kind == AudioSourceKind.systemOutput
        ? 'System audio · ${source.name}'
        : source.name;
    return Opacity(
      opacity: enabled ? 1.0 : 0.7,
      child: Pill(
        label: label,
        dotColor: ColorTokens.accent,
        trailing: enabled ? const Icon(Icons.arrow_drop_down, size: 12) : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

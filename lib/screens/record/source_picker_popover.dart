import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/audio_source.dart';

/// Anchored menu shown by `showMenu` from the SourcePill. Grouped by kind.
class SourcePickerPopover {
  SourcePickerPopover._();

  static Future<AudioSource?> show({
    required BuildContext anchorContext,
    required List<AudioSource> sources,
    required AudioSource? active,
  }) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final anchorPos = anchorBox.localToGlobal(Offset.zero);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        anchorPos.dx,
        anchorPos.dy + anchorBox.size.height + 6,
        anchorBox.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    final systemOutputs =
        sources.where((s) => s.kind == AudioSourceKind.systemOutput).toList();
    final mics = sources.where((s) => s.kind != AudioSourceKind.systemOutput).toList();

    final items = <PopupMenuEntry<AudioSource>>[];
    if (systemOutputs.isNotEmpty) {
      items.add(_section('System output'));
      for (final s in systemOutputs) {
        items.add(_row(s, isActive: s == active));
      }
    }
    if (mics.isNotEmpty) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(_section('Microphones'));
      for (final s in mics) {
        items.add(_row(s, isActive: s == active));
      }
    }

    return showMenu<AudioSource>(
      context: anchorContext,
      position: position,
      color: ColorTokens.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      elevation: 16,
      items: items,
    );
  }

  static PopupMenuEntry<AudioSource> _section(String title) {
    return PopupMenuItem<AudioSource>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          color: ColorTokens.inkFaint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static PopupMenuEntry<AudioSource> _row(AudioSource s, {required bool isActive}) {
    return PopupMenuItem<AudioSource>(
      value: s,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? ColorTokens.accentSoft : ColorTokens.cream2,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              s.kind == AudioSourceKind.systemOutput ? Icons.speaker : Icons.mic,
              size: 14,
              color: ColorTokens.ink,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              s.name,
              style: const TextStyle(fontSize: 12, color: ColorTokens.ink),
            ),
          ),
          if (isActive) const Icon(Icons.check, size: 14, color: ColorTokens.accent),
        ],
      ),
    );
  }
}

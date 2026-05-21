import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';

/// Renders a transcript as paragraphs split on blank lines or sentence
/// boundaries. Shows shimmer placeholders while transcribing.
class TranscriptView extends StatelessWidget {
  const TranscriptView({
    required this.transcript,
    required this.isTranscribing,
    super.key,
  });

  final String transcript;
  final bool isTranscribing;

  @override
  Widget build(BuildContext context) {
    if (isTranscribing && transcript.isEmpty) {
      return const _TranscribingPlaceholder();
    }
    final paragraphs = _paragraphs(transcript);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final p in paragraphs) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Text(p, style: AppTextStyles.transcript),
            ),
          ],
        ],
      ),
    );
  }

  static List<String> _paragraphs(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <String>[];
    if (trimmed.contains('\n\n')) {
      return trimmed
          .split(RegExp(r'\n\s*\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    final out = <String>[];
    for (var i = 0; i < sentences.length; i += 3) {
      out.add(sentences.skip(i).take(3).join(' '));
    }
    return out;
  }
}

class _TranscribingPlaceholder extends StatelessWidget {
  const _TranscribingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TranscribingChip(),
        SizedBox(height: Spacing.md),
        _ShimmerBar(width: 0.92),
        SizedBox(height: 10),
        _ShimmerBar(width: 0.88),
        SizedBox(height: 10),
        _ShimmerBar(width: 0.60),
      ],
    );
  }
}

class _TranscribingChip extends StatelessWidget {
  const _TranscribingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: ColorTokens.cream2,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ColorTokens.accent),
              backgroundColor: ColorTokens.accentSoft,
            ),
          ),
          SizedBox(width: Spacing.sm),
          Text(
            'Transcribing locally with Whisper…',
            style: TextStyle(fontSize: 12, color: ColorTokens.ink),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: ColorTokens.cream2,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
    );
  }
}

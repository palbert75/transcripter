import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/recording.dart';
import '../../widgets/soft_card.dart';

class LibraryRow extends StatelessWidget {
  const LibraryRow({
    required this.recording,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Recording recording;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final snippet = recording.transcript.trim().isEmpty
        ? 'No transcript yet.'
        : recording.transcript.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    recording.title.isEmpty ? 'Untitled' : recording.title,
                    style: const TextStyle(
                      fontFamily: 'New York',
                      fontFamilyFallback: <String>['Georgia', 'serif'],
                      fontSize: 14,
                      color: ColorTokens.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDuration(recording.durationSeconds),
                  style: AppTextStyles.mono,
                ),
                const SizedBox(width: Spacing.xs),
                _DeleteButton(onPressed: () => _confirmAndDelete(context)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatTime(recording.createdAt)} · ${recording.sourceName}',
              style: AppTextStyles.meta,
            ),
            const SizedBox(height: 4),
            Text(
              snippet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'New York',
                fontFamilyFallback: <String>['Georgia', 'serif'],
                fontSize: 12,
                color: ColorTokens.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final shownTitle = recording.title.trim().isEmpty
        ? 'this recording'
        : '"${recording.title.trim()}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(
          'This will permanently remove $shownTitle and its audio file.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime when) {
    final local = when.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = ((h + 11) % 12) + 1;
    return '$h12:$m $period';
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Delete recording',
      child: SizedBox(
        width: 28,
        height: 28,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            hoverColor: ColorTokens.danger.withValues(alpha: 0.08),
            onTap: onPressed,
            child: const Center(
              child: Icon(
                Icons.delete_outline,
                size: 16,
                color: ColorTokens.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

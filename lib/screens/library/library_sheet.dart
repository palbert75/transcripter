import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/recording.dart';
import '../../widgets/tonal_icon_button.dart';
import 'library_row.dart';

class LibrarySheet extends StatefulWidget {
  const LibrarySheet({
    required this.recordings,
    required this.onTap,
    required this.onDelete,
    required this.onClose,
    super.key,
  });

  final List<Recording> recordings;
  final void Function(Recording) onTap;

  /// Called when the user confirms deletion. The parent is responsible for
  /// actually removing the file (e.g. via `AppController.deleteRecording`).
  /// The sheet has already removed the row from its local state by then.
  final Future<void> Function(Recording) onDelete;
  final VoidCallback onClose;

  @override
  State<LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends State<LibrarySheet> {
  late List<Recording> _recordings = List<Recording>.of(widget.recordings);

  @override
  void didUpdateWidget(covariant LibrarySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent re-pushes the sheet with a different list, follow it.
    if (!identical(oldWidget.recordings, widget.recordings)) {
      _recordings = List<Recording>.of(widget.recordings);
    }
  }

  Future<void> _handleDelete(Recording rec) async {
    setState(() => _recordings.removeWhere((r) => r.id == rec.id));
    try {
      await widget.onDelete(rec);
    } on Object catch (error) {
      if (!mounted) return;
      // Re-insert and surface the failure so the user knows the file is still there.
      setState(() => _recordings = List<Recording>.of(widget.recordings));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(_recordings);

    return Scaffold(
      backgroundColor: ColorTokens.cream,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.md, Spacing.md, Spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  const Text(
                    'Library',
                    style: TextStyle(
                      fontFamily: 'New York',
                      fontFamilyFallback: <String>['Georgia', 'serif'],
                      fontSize: 18,
                      color: ColorTokens.ink,
                    ),
                  ),
                  const Spacer(),
                  TonalIconButton(
                    icon: Icons.close, onPressed: widget.onClose, tooltip: 'Close'),
                ],
              ),
            ),
            Expanded(
              child: _recordings.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.md, 0, Spacing.md, Spacing.md,
                      ),
                      children: <Widget>[
                        for (final group in groups) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              4, Spacing.md, 4, Spacing.xs,
                            ),
                            child: Text(group.label, style: AppTextStyles.meta),
                          ),
                          for (final r in group.items) ...<Widget>[
                            LibraryRow(
                              recording: r,
                              onTap: () => widget.onTap(r),
                              onDelete: () => _handleDelete(r),
                            ),
                            const SizedBox(height: Spacing.xs),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_Group> _groupByDate(List<Recording> recs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final groups = <String, List<Recording>>{
      'TODAY': <Recording>[],
      'YESTERDAY': <Recording>[],
      'LAST WEEK': <Recording>[],
      'OLDER': <Recording>[],
    };
    for (final r in recs) {
      final d = DateTime(r.createdAt.toLocal().year,
          r.createdAt.toLocal().month, r.createdAt.toLocal().day);
      if (d == today) {
        groups['TODAY']!.add(r);
      } else if (d == yesterday) {
        groups['YESTERDAY']!.add(r);
      } else if (d.isAfter(lastWeek)) {
        groups['LAST WEEK']!.add(r);
      } else {
        groups['OLDER']!.add(r);
      }
    }
    return groups.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => _Group(e.key, e.value))
        .toList();
  }
}

class _Group {
  _Group(this.label, this.items);
  final String label;
  final List<Recording> items;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('◔',
                style: TextStyle(fontSize: 36, color: ColorTokens.inkFaint)),
            SizedBox(height: 12),
            Text(
              'No recordings yet',
              style: TextStyle(
                fontFamily: 'New York',
                fontFamilyFallback: <String>['Georgia', 'serif'],
                fontSize: 18,
                color: ColorTokens.ink,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your recordings and transcripts will appear here. Tap the record button to make your first one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ColorTokens.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/recording.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/tonal_icon_button.dart';
import 'session_toolbar.dart';
import 'transcript_view.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    required this.recording,
    required this.isTranscribing,
    required this.onBack,
    required this.onDelete,
    required this.onExport,
    required this.onCopy,
    required this.onTitleChanged,
    super.key,
  });

  final Recording recording;
  final bool isTranscribing;
  final VoidCallback onBack;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onCopy;
  final void Function(String newTitle) onTitleChanged;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final TextEditingController _titleCtl = TextEditingController(
    text: widget.recording.title,
  );
  final FocusNode _titleFocus = FocusNode();

  @override
  void didUpdateWidget(covariant SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recording.title != widget.recording.title &&
        !_titleFocus.hasFocus) {
      _titleCtl.text = widget.recording.title;
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.recording.title.trim().isNotEmpty;
    final showUntitled = widget.isTranscribing && !hasTitle;

    return Scaffold(
      backgroundColor: ColorTokens.cream,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(
              onBack: widget.onBack,
              onExport: widget.onExport,
              onCopy: widget.onCopy,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  0,
                  Spacing.md,
                  Spacing.md,
                ),
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.xl,
                    Spacing.lg,
                    Spacing.xl,
                    Spacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _metaLine(widget.recording),
                        style: AppTextStyles.meta,
                      ),
                      const SizedBox(height: Spacing.sm),
                      if (showUntitled)
                        const Text(
                          'Untitled recording',
                          style: TextStyle(
                            fontFamily: 'New York',
                            fontFamilyFallback: <String>['Georgia', 'serif'],
                            fontSize: 24,
                            color: ColorTokens.inkFaint,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        TextField(
                          controller: _titleCtl,
                          focusNode: _titleFocus,
                          style: AppTextStyles.sessionTitle,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: widget.onTitleChanged,
                          onEditingComplete: () =>
                              widget.onTitleChanged(_titleCtl.text),
                        ),
                      const SizedBox(height: Spacing.md),
                      Expanded(
                        child: TranscriptView(
                          transcript: widget.recording.transcript,
                          isTranscribing: widget.isTranscribing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SessionToolbar(
              onDelete: widget.onDelete,
              onExport: widget.onExport,
              onCopy: widget.onCopy,
              onDone: widget.onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onExport,
    required this.onCopy,
  });

  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        Spacing.sm,
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                '‹ Record',
                style: TextStyle(fontSize: 12, color: ColorTokens.accent),
              ),
            ),
          ),
          const Spacer(),
          TonalIconButton(
            icon: Icons.download_outlined,
            onPressed: onExport,
            tooltip: 'Export',
          ),
          TonalIconButton(
            icon: Icons.copy_outlined,
            onPressed: onCopy,
            tooltip: 'Copy',
          ),
          TonalIconButton(
            icon: Icons.more_horiz,
            onPressed: () {},
            tooltip: 'More',
          ),
        ],
      ),
    );
  }
}

String _metaLine(Recording r) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = r.createdAt.toLocal();
  final today = DateTime.now();
  final isToday =
      d.year == today.year && d.month == today.month && d.day == today.day;
  final datePart = isToday
      ? 'TODAY'
      : '${two(d.year)}-${two(d.month)}-${two(d.day)}';
  final timePart = '${two(d.hour)}:${two(d.minute)}';
  final durM = r.durationSeconds ~/ 60;
  final durS = r.durationSeconds % 60;
  return '$datePart · $timePart · ${two(durM)}:${two(durS)} · ${r.sourceName}'
      .toUpperCase();
}

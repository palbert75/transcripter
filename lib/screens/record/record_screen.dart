import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/audio_source.dart';
import '../../models/recorder_state.dart';
import '../../models/setup_problem.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/tonal_icon_button.dart';
import 'record_button.dart';
import 'source_pill.dart';
import 'waveform_strip.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    required this.source,
    required this.allSources,
    required this.state,
    required this.elapsed,
    required this.problem,
    required this.recordingsCount,
    required this.onStart,
    required this.onStop,
    required this.onPickSource,
    required this.onOpenLibrary,
    required this.onOpenSettings,
    required this.onResolveProblem,
    super.key,
  });

  /// Convenience constructor for widget tests and previews.
  const RecordScreen.preview({
    required this.source,
    super.key,
  })  : allSources = const <AudioSource>[],
        state = RecorderState.idle,
        elapsed = Duration.zero,
        problem = null,
        recordingsCount = 0,
        onStart = _noop,
        onStop = _noop,
        onPickSource = _noopPick,
        onOpenLibrary = _noop,
        onOpenSettings = _noop,
        onResolveProblem = _noopProblem;

  final AudioSource source;
  final List<AudioSource> allSources;
  final RecorderState state;
  final Duration elapsed;
  final SetupProblem? problem;
  final int recordingsCount;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final Future<void> Function(BuildContext context) onPickSource;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenSettings;
  final void Function(SetupProblem problem) onResolveProblem;

  static void _noop() {}
  static Future<void> _noopPick(BuildContext _) async {}
  static void _noopProblem(SetupProblem _) {}

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  @override
  Widget build(BuildContext context) {
    final isRecording = widget.state == RecorderState.recording ||
        widget.state == RecorderState.stopping;
    final blocked = widget.problem != null;

    return Scaffold(
      backgroundColor: ColorTokens.cream,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(
              enabled: !isRecording && !blocked,
              onLibrary: widget.onOpenLibrary,
              onSettings: widget.onOpenSettings,
            ),
            if (blocked)
              ErrorBanner(
                problem: widget.problem!,
                onAction: () => widget.onResolveProblem(widget.problem!),
              ),
            Expanded(
              child: IgnorePointer(
                ignoring: blocked,
                child: Opacity(
                  opacity: blocked ? 0.35 : 1.0,
                  child: _Center(
                    source: widget.source,
                    sourceEnabled: !isRecording,
                    onPickSource: widget.onPickSource,
                    isRecording: isRecording,
                    elapsed: widget.elapsed,
                    onTapRecord: isRecording ? widget.onStop : widget.onStart,
                  ),
                ),
              ),
            ),
            _Footer(
              isRecording: isRecording,
              recordingsCount: widget.recordingsCount,
              onOpenLibrary: widget.onOpenLibrary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.enabled,
    required this.onLibrary,
    required this.onSettings,
  });

  final bool enabled;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.md, Spacing.sm),
      child: Row(
        children: <Widget>[
          const Icon(Icons.fiber_manual_record, size: 8, color: ColorTokens.accent),
          const SizedBox(width: 6),
          const Text(
            'Transcripter',
            style: TextStyle(
              fontFamily: 'New York',
              fontFamilyFallback: <String>['Georgia', 'serif'],
              fontSize: 14,
              color: ColorTokens.ink,
            ),
          ),
          const Spacer(),
          TonalIconButton(
            icon: Icons.search,
            onPressed: enabled ? onLibrary : null,
            tooltip: 'Library',
          ),
          const SizedBox(width: 2),
          TonalIconButton(
            icon: Icons.settings_outlined,
            onPressed: enabled ? onSettings : null,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({
    required this.source,
    required this.sourceEnabled,
    required this.onPickSource,
    required this.isRecording,
    required this.elapsed,
    required this.onTapRecord,
  });

  final AudioSource source;
  final bool sourceEnabled;
  final Future<void> Function(BuildContext anchorCtx) onPickSource;
  final bool isRecording;
  final Duration elapsed;
  final VoidCallback onTapRecord;

  @override
  Widget build(BuildContext context) {
    final timer = _formatDuration(elapsed);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Builder(
            builder: (anchorCtx) => SourcePill(
              source: source,
              enabled: sourceEnabled,
              onTap: () => onPickSource(anchorCtx),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          RecordButton(
            isRecording: isRecording,
            onTap: onTapRecord,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            timer,
            style: isRecording
                ? AppTextStyles.timer
                : AppTextStyles.timer.copyWith(color: ColorTokens.inkFaint),
          ),
          const SizedBox(height: Spacing.sm),
          if (isRecording)
            const WaveformStrip()
          else
            const Text(
              'Tap to record',
              style: TextStyle(fontSize: 11, color: ColorTokens.inkSoft),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isRecording,
    required this.recordingsCount,
    required this.onOpenLibrary,
  });

  final bool isRecording;
  final int recordingsCount;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final left = isRecording
        ? const Text('● Recording · 16 kHz mono',
            style: TextStyle(fontSize: 11, color: ColorTokens.inkSoft))
        : Text(
            '$recordingsCount recent recording${recordingsCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11, color: ColorTokens.inkSoft),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ColorTokens.line)),
      ),
      child: Row(
        children: <Widget>[
          left,
          const Spacer(),
          InkWell(
            onTap: isRecording ? null : onOpenLibrary,
            child: Text(
              isRecording ? 'Tap button to stop' : 'Open library →',
              style: TextStyle(
                fontSize: 11,
                color: isRecording ? ColorTokens.inkSoft : ColorTokens.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  final h = d.inHours;
  return h > 0 ? '${two(h)}:$m:$s' : '$m:$s';
}

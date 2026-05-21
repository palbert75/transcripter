import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/theme.dart';
import 'models/audio_source.dart';
import 'models/recording.dart';
import 'models/setup_problem.dart';
import 'screens/help/blackhole_setup_view.dart';
import 'screens/library/library_sheet.dart';
import 'screens/record/record_screen.dart';
import 'screens/record/source_picker_popover.dart';
import 'screens/session/session_screen.dart';
import 'screens/settings/settings_sheet.dart';
import 'services/library_service.dart';
import 'services/paths_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final paths = PathsService();
  final controller = AppController(
    paths: paths,
    library: LibraryService(paths: paths),
    settingsSvc: SettingsService(paths: paths),
  );
  await controller.bootstrap();
  runApp(TranscripterApp(controller: controller));
}

class TranscripterApp extends StatelessWidget {
  const TranscripterApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transcripter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _RootShell(controller: controller),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell({required this.controller});
  final AppController controller;

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  AppController get c => widget.controller;

  Future<void> _pickSource(BuildContext anchorContext) async {
    final picked = await SourcePickerPopover.show(
      anchorContext: anchorContext,
      sources: c.sources,
      active: c.selectedSource,
    );
    if (picked != null) {
      await c.selectSource(picked);
    }
  }

  Future<void> _start() async {
    final rec = await c.startRecording();
    if (rec == null) return;
  }

  Future<void> _stop() async {
    final completed = await c.stopRecording();
    if (completed == null || !mounted) return;
    _maybeWarnSilent();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SessionRoute(
          controller: c,
          initial: completed,
        ),
      ),
    );
  }

  void _maybeWarnSilent() {
    final peak = c.lastRecordingPeak;
    if (peak == null || peak >= 100) return;
    final usingBlackHole = c.selectedSource?.name
            .toLowerCase()
            .contains('blackhole') ??
        false;
    final detail = usingBlackHole
        ? "BlackHole didn't receive any audio. Set macOS Output to a "
            'Multi-Output Device that includes BlackHole, then try again.'
        : 'No audio was captured. Check microphone permission for '
            'Transcripter in System Settings → Privacy & Security.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('Recording was silent. $detail'),
        action: usingBlackHole
            ? SnackBarAction(
                label: 'Setup help',
                onPressed: _openBlackHoleSetup,
              )
            : null,
      ),
    );
  }

  void _openBlackHoleSetup() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlackHoleSetupView(controller: c),
    ));
  }

  Future<void> _openLibrary() async {
    final recs = await c.listRecordings();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: LibrarySheet(
            recordings: recs,
            onClose: () => Navigator.pop(context),
            onDelete: (rec) => c.deleteRecording(rec),
            onTap: (rec) async {
              Navigator.pop(context);
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => _SessionRoute(
                  controller: c,
                  initial: rec,
                  skipTranscribe: true,
                ),
              ));
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickPreferredFromSettings(BuildContext context) async {
    final picked = await showDialog<AudioSource>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Default audio source'),
        children: <Widget>[
          for (final s in c.sources)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogCtx, s),
              child: Text(s.name),
            ),
        ],
      ),
    );
    if (picked != null) {
      await c.selectSource(picked);
    }
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ListenableBuilder rebuilds the sheet whenever the controller fires
      // notifyListeners — picking a new source or a new model is reflected
      // immediately instead of waiting for the user to close and reopen.
      builder: (_) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SettingsSheet(
            settings: c.settings,
            preferredSource: c.selectedSource,
            allSources: c.sources,
            modelsDir: c.modelsDir,
            onClose: () => Navigator.pop(context),
            onSettingsChanged: (s) => c.changeSettings(s),
            onPickPreferredSource: () {
              unawaited(_pickPreferredFromSettings(context));
            },
            onOpenBlackHoleSetup: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BlackHoleSetupView(controller: c),
              ));
            },
          ),
        ),
      ),
      ),
    );
  }

  void _handleProblem(SetupProblem problem) {
    if (problem == SetupProblem.noSystemAudioDevice) {
      _openBlackHoleSetup();
    } else {
      _openSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = c.selectedSource ??
        const AudioSource(
          name: 'No audio source',
          avFoundationIndex: -1,
          kind: AudioSourceKind.unknown,
        );
    return RecordScreen(
      source: source,
      allSources: c.sources,
      state: c.recorderState,
      elapsed: c.elapsed,
      problem: c.problem,
      recordingsCount: c.recordingsCount,
      onStart: _start,
      onStop: _stop,
      onPickSource: _pickSource,
      onOpenLibrary: _openLibrary,
      onOpenSettings: _openSettings,
      onResolveProblem: _handleProblem,
    );
  }
}

class _SessionRoute extends StatefulWidget {
  const _SessionRoute({
    required this.controller,
    required this.initial,
    this.skipTranscribe = false,
  });

  final AppController controller;
  final Recording initial;
  final bool skipTranscribe;

  @override
  State<_SessionRoute> createState() => _SessionRouteState();
}

class _SessionRouteState extends State<_SessionRoute> {
  late Recording _rec = widget.initial;
  bool _transcribing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.skipTranscribe && _rec.transcript.isEmpty) {
      _transcribing = true;
      // Defer to post-frame so transcribe()'s synchronous error paths cannot
      // call notifyListeners during the build that created this route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runTranscription();
      });
    }
  }

  Future<void> _runTranscription() async {
    try {
      final updated = await widget.controller.transcribe(_rec);
      if (!mounted) return;
      setState(() {
        _rec = updated;
        _transcribing = false;
      });
    } on TranscribeUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      setState(() => _transcribing = false);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transcription failed: $error')),
      );
      setState(() => _transcribing = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _rec.transcript));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied to clipboard')),
    );
  }

  Future<void> _export() async {
    final choice = await showDialog<_ExportChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _ExportChoice.transcript),
            child: const Text('Transcript (.txt)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _ExportChoice.audio),
            child: const Text('Audio (.wav)'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final outPath = await _writeExport(choice);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $outPath')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  Future<String> _writeExport(_ExportChoice choice) async {
    final downloads = Directory(
      '${Platform.environment['HOME'] ?? ''}/Downloads',
    );
    if (!downloads.existsSync()) {
      await downloads.create(recursive: true);
    }
    final stem = _safeStem(_rec);
    switch (choice) {
      case _ExportChoice.transcript:
        final path = '${downloads.path}/$stem.txt';
        await File(path).writeAsString(
          '${_rec.title}\n\n${_rec.transcript}\n',
        );
        return path;
      case _ExportChoice.audio:
        final source = File(_rec.wavPath);
        if (!source.existsSync()) {
          throw const FileSystemException('Original WAV is missing');
        }
        final path = '${downloads.path}/$stem.wav';
        await source.copy(path);
        return path;
    }
  }

  static String _safeStem(Recording r) {
    final base = r.title.trim().isEmpty ? r.id : r.title.trim();
    return base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<void> _delete() async {
    await widget.controller.deleteRecording(_rec);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _renameTo(String title) async {
    final updated = _rec.copyWith(title: title);
    await widget.controller.updateRecording(updated);
    if (!mounted) return;
    setState(() => _rec = updated);
  }

  @override
  Widget build(BuildContext context) {
    return SessionScreen(
      recording: _rec,
      isTranscribing: _transcribing,
      onBack: () => Navigator.of(context).pop(),
      onDelete: _delete,
      onExport: _export,
      onCopy: _copy,
      onTitleChanged: _renameTo,
    );
  }
}

enum _ExportChoice { transcript, audio }


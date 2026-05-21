import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/theme.dart';
import 'models/audio_source.dart';
import 'models/recording.dart';
import 'models/setup_problem.dart';
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

  void _onChanged() => setState(() {});

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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SessionRoute(
          controller: c,
          initial: completed,
        ),
      ),
    );
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
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SettingsSheet(
            settings: c.settings,
            preferredSource: c.selectedSource,
            allSources: c.sources,
            onClose: () => Navigator.pop(context),
            onSettingsChanged: (s) => c.changeSettings(s),
            onPickPreferredSource: () {
              unawaited(_pickPreferredFromSettings(context));
            },
          ),
        ),
      ),
    );
  }

  void _handleProblem(SetupProblem problem) {
    _openSettings();
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
      _runTranscription();
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
    final txtPath = _rec.wavPath.replaceAll(RegExp(r'\.wav$'), '.txt');
    await File(txtPath).writeAsString(
      '${_rec.title}\n\n${_rec.transcript}\n',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported to $txtPath')),
    );
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

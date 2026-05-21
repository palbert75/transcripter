import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../services/settings_service.dart';

class AdvancedSettingsView extends StatefulWidget {
  const AdvancedSettingsView({
    required this.settings,
    required this.onSettingsChanged,
    super.key,
  });

  final AppSettings settings;
  final void Function(AppSettings) onSettingsChanged;

  @override
  State<AdvancedSettingsView> createState() => _AdvancedSettingsViewState();
}

class _AdvancedSettingsViewState extends State<AdvancedSettingsView> {
  late final TextEditingController _ffmpeg =
      TextEditingController(text: widget.settings.ffmpegPathOverride ?? '');
  late final TextEditingController _whisper =
      TextEditingController(text: widget.settings.whisperPathOverride ?? '');
  late final TextEditingController _model =
      TextEditingController(text: widget.settings.modelPathOverride ?? '');

  @override
  void dispose() {
    _ffmpeg.dispose();
    _whisper.dispose();
    _model.dispose();
    super.dispose();
  }

  void _save() {
    final ffmpeg = _ffmpeg.text.trim();
    final whisper = _whisper.text.trim();
    final model = _model.text.trim();
    widget.onSettingsChanged(widget.settings.copyWith(
      ffmpegPathOverride: ffmpeg.isEmpty ? null : ffmpeg,
      clearFfmpegOverride: ffmpeg.isEmpty,
      whisperPathOverride: whisper.isEmpty ? null : whisper,
      clearWhisperOverride: whisper.isEmpty,
      modelPathOverride: model.isEmpty ? null : model,
      clearModelOverride: model.isEmpty,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.cream,
      appBar: AppBar(
        backgroundColor: ColorTokens.cream,
        elevation: 0,
        title: const Text('Tool paths', style: AppTextStyles.uiTitle),
        iconTheme: const IconThemeData(color: ColorTokens.ink),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          children: <Widget>[
            const Text(
              'Leave blank to use the auto-detected path. Useful only for non-Homebrew installs.',
              style: TextStyle(fontSize: 12, color: ColorTokens.inkSoft, height: 1.5),
            ),
            const SizedBox(height: Spacing.lg),
            _Field(label: 'ffmpeg', controller: _ffmpeg),
            const SizedBox(height: Spacing.md),
            _Field(label: 'whisper-cli', controller: _whisper),
            const SizedBox(height: Spacing.md),
            _Field(label: 'Whisper model (.bin)', controller: _model),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: () {
                _save();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

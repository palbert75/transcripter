import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/audio_source.dart';
import '../../services/settings_service.dart';
import '../../widgets/tonal_icon_button.dart';
import 'advanced_settings_view.dart';
import 'models_view.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    required this.settings,
    required this.preferredSource,
    required this.allSources,
    required this.modelsDir,
    required this.onSettingsChanged,
    required this.onPickPreferredSource,
    required this.onClose,
    super.key,
  });

  final AppSettings settings;
  final AudioSource? preferredSource;
  final List<AudioSource> allSources;
  final Directory modelsDir;
  final void Function(AppSettings) onSettingsChanged;
  final VoidCallback onPickPreferredSource;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
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
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'New York',
                      fontFamilyFallback: <String>['Georgia', 'serif'],
                      fontSize: 18,
                      color: ColorTokens.ink,
                    ),
                  ),
                  const Spacer(),
                  TonalIconButton(icon: Icons.close, onPressed: onClose, tooltip: 'Close'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                children: <Widget>[
                  _Group(title: 'Recording', rows: <Widget>[
                    _Row(
                      title: 'Default audio source',
                      subtitle: 'Used when you open the app',
                      value: preferredSource?.name ?? 'Not set',
                      onTap: onPickPreferredSource,
                    ),
                  ]),
                  const SizedBox(height: Spacing.md),
                  _Group(title: 'Transcription', rows: <Widget>[
                    _Row(
                      title: 'Speech model',
                      subtitle: 'Download and pick the Whisper model',
                      value: _modelLabel(settings.modelPathOverride),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ModelsView(
                          modelsDir: modelsDir,
                          activePath: settings.modelPathOverride,
                          onModelSelected: (path) {
                            if (path == null) {
                              onSettingsChanged(
                                settings.copyWith(clearModelOverride: true),
                              );
                            } else {
                              onSettingsChanged(
                                settings.copyWith(modelPathOverride: path),
                              );
                            }
                          },
                        ),
                      )),
                    ),
                    _Row(
                      title: 'Language',
                      value: settings.language,
                      onTap: () => _editLanguage(context, settings, onSettingsChanged),
                    ),
                  ]),
                  const SizedBox(height: Spacing.md),
                  _Group(title: 'Advanced', rows: <Widget>[
                    _Row(
                      title: 'Tool paths',
                      subtitle: 'ffmpeg, whisper-cli, model — auto-detected if blank',
                      value: 'Edit',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => AdvancedSettingsView(
                          settings: settings,
                          onSettingsChanged: onSettingsChanged,
                        ),
                      )),
                    ),
                  ]),
                  const SizedBox(height: Spacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _modelLabel(String? overridePath) {
    if (overridePath == null || overridePath.isEmpty) return 'Auto';
    final slash = overridePath.lastIndexOf('/');
    return slash >= 0 ? overridePath.substring(slash + 1) : overridePath;
  }

  Future<void> _editLanguage(
    BuildContext context,
    AppSettings current,
    void Function(AppSettings) onChanged,
  ) async {
    final ctl = TextEditingController(text: current.language);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transcription language'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            helperText: 'Two-letter language code (e.g. en, fr, es)',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      onChanged(current.copyWith(language: result));
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 0, 0, Spacing.xs),
          child: Text(title.toUpperCase(), style: AppTextStyles.meta),
        ),
        Container(
          decoration: BoxDecoration(
            color: ColorTokens.paper,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D3C2814),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: ColorTokens.lineSoft),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: const TextStyle(fontSize: 12, color: ColorTokens.ink)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 10, color: ColorTokens.inkSoft)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            Text(value,
                style: const TextStyle(fontSize: 12, color: ColorTokens.inkSoft)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: ColorTokens.inkFaint),
          ],
        ),
      ),
    );
  }
}

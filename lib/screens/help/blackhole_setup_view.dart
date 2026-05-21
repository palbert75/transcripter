import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/audio_source.dart';
import '../../services/wav_signal_check.dart';

/// Step-by-step walkthrough for capturing system audio via BlackHole.
/// Surfaces:
///   - Whether BlackHole is detected in the audio device list.
///   - One-click shortcuts to Audio MIDI Setup and System Settings → Sound.
///   - A probe recording that verifies BlackHole is actually receiving audio.
class BlackHoleSetupView extends StatefulWidget {
  const BlackHoleSetupView({required this.controller, super.key});

  final AppController controller;

  @override
  State<BlackHoleSetupView> createState() => _BlackHoleSetupViewState();
}

class _BlackHoleSetupViewState extends State<BlackHoleSetupView> {
  bool _testing = false;
  WavSignalReport? _lastReport;
  String? _testError;

  AudioSource? get _blackHole {
    for (final s in widget.controller.sources) {
      if (s.name.toLowerCase().contains('blackhole')) return s;
    }
    return null;
  }

  Future<void> _openAudioMidiSetup() async {
    await Process.run('open', <String>['-a', 'Audio MIDI Setup']);
  }

  Future<void> _openSoundSettings() async {
    // System Settings deep link for Sound. Falls back to opening the app
    // if the URL scheme isn't recognized on this OS version.
    final r = await Process.run('open', <String>[
      'x-apple.systempreferences:com.apple.preference.sound',
    ]);
    if (r.exitCode != 0) {
      await Process.run('open', <String>['-b', 'com.apple.systempreferences']);
    }
  }

  Future<void> _runTest() async {
    final bh = _blackHole;
    if (bh == null) {
      setState(() {
        _testError = "BlackHole isn't in the audio device list yet. "
            'Install it with `brew install --cask blackhole-2ch`, then '
            'reopen this screen.';
        _lastReport = null;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testError = null;
      _lastReport = null;
    });
    try {
      final report = await widget.controller.testRoutingFor(bh);
      if (!mounted) return;
      setState(() {
        _lastReport = report;
        _testing = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _testError = error.toString();
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bh = _blackHole;
    final bhInstalled = bh != null;

    return Scaffold(
      backgroundColor: ColorTokens.cream,
      appBar: AppBar(
        backgroundColor: ColorTokens.cream,
        elevation: 0,
        title: const Text('Capture system audio', style: AppTextStyles.uiTitle),
        iconTheme: const IconThemeData(color: ColorTokens.ink),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          children: <Widget>[
            const Text(
              "macOS doesn't let apps record speaker output directly. "
              'BlackHole is a free virtual cable that captures whatever the '
              'system plays — once you point macOS at it.',
              style: TextStyle(
                fontSize: 12,
                color: ColorTokens.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            _StepCard(
              number: 1,
              title: 'Install BlackHole 2ch',
              done: bhInstalled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SelectableText(
                    'brew install --cask blackhole-2ch',
                    style: AppTextStyles.mono,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bhInstalled
                        ? 'Detected: ${bh.name}'
                        : 'Not detected yet. Restart Transcripter after installing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: bhInstalled ? ColorTokens.success : ColorTokens.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            _StepCard(
              number: 2,
              title: 'Create a Multi-Output Device',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'In Audio MIDI Setup, click + → Create Multi-Output '
                    'Device. Tick your speakers AND BlackHole 2ch. Set your '
                    'speakers as the Master Device. Enable Drift Correction '
                    'on the BlackHole row.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorTokens.inkSoft,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  OutlinedButton.icon(
                    onPressed: _openAudioMidiSetup,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Open Audio MIDI Setup'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            _StepCard(
              number: 3,
              title: 'Send macOS audio to it',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'System Settings → Sound → Output → pick the Multi-'
                    'Output Device. You still hear audio through your '
                    'speakers, and BlackHole quietly receives a copy.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorTokens.inkSoft,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  OutlinedButton.icon(
                    onPressed: _openSoundSettings,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Open Sound Settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            _StepCard(
              number: 4,
              title: 'Verify it works',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Start playing audio anywhere (YouTube, Music, etc.) '
                    'then tap below. Transcripter records 3 seconds from '
                    'BlackHole and checks whether anything came through.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorTokens.inkSoft,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        onPressed: _testing ? null : _runTest,
                        child: Text(_testing ? 'Listening…' : 'Test routing'),
                      ),
                      const SizedBox(width: Spacing.md),
                      if (_testing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (_testError != null) ...<Widget>[
                    const SizedBox(height: Spacing.sm),
                    _ResultLine(success: false, message: _testError!),
                  ],
                  if (_lastReport != null) ...<Widget>[
                    const SizedBox(height: Spacing.sm),
                    _ResultLine(
                      success: !_lastReport!.isSilent,
                      message: !_lastReport!.isSilent
                          ? 'Audio detected (peak ${_lastReport!.maxAbs}/32767). '
                              'Routing is working — recordings will capture system audio.'
                          : 'BlackHole is still silent. Double-check step 3: '
                              'macOS Output must be the Multi-Output Device while you '
                              'play audio.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.child,
    this.done = false,
  });

  final int number;
  final String title;
  final Widget child;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: ColorTokens.paper,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: ColorTokens.lineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? ColorTokens.success : ColorTokens.cream2,
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$number',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.ink,
                    ),
                  ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.ink,
                  ),
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.success, required this.message});

  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          success ? Icons.check_circle : Icons.error_outline,
          size: 16,
          color: success ? ColorTokens.success : ColorTokens.danger,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: success ? ColorTokens.success : ColorTokens.danger,
            ),
          ),
        ),
      ],
    );
  }
}

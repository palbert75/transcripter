# Plan 1 · UI Refactor & Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current single-file developer-facing UI with the warm-minimalist consumer design from the spec, wired to the user's already-installed FFmpeg and Whisper. The app must remain fully functional after each task.

**Architecture:** Split the monolithic `lib/main.dart` into a layered structure: `models/` for value types, `services/` for I/O (subprocesses, filesystem), `app/` for theme, `screens/` for per-surface UI, `widgets/` for reusables. State is held by the top-level `RecordScreen` and passed down — no state management package needed at this size. Subprocess wrappers are injectable for testing.

**Tech Stack:** Flutter 3 / Dart 3, Material 3, `path_provider`, system FFmpeg + whisper-cli (located via PATH auto-detect with manual override in Settings → Advanced).

**Scope notes:** Plan 1 does **not** bundle binaries, download the Whisper model, install BlackHole, or use any native macOS plugin. Those are Plans 2, 3, and 4. The app still requires the user to install FFmpeg, whisper-cli, BlackHole, and a Whisper model file manually (current README instructions). What changes is the look, the IA, and the code structure.

**Reference:** `docs/superpowers/specs/2026-05-21-transcripter-redesign-design.md` sections 2, 3, 4 (excluding 4.5 search, full export menu, scrubbable waveform — see "Deferred to later plans" below).

**Deferred to later plans:**
- Library search box (just the unfiltered grouped list for Plan 1).
- Export menu with `.md`/`.srt` (Plan 1 ships `.txt` export + clipboard copy only).
- Scrubbable waveform with playback head (Plan 1 ships a static waveform image + play/pause that uses macOS default player via `open`).
- Auto-transcribe toggle (Plan 1 always auto-transcribes).
- Model download/management UI (Plan 2).
- BlackHole detection / install / uninstall (Plans 3 & 4).
- Native mic-permission API (Plan 3). Plan 1 detects the failure from FFmpeg's stderr and shows the same banner.

---

## File Structure

```
lib/
  main.dart                          # entry; loads theme, shows RecordScreen
  app/
    theme.dart                       # ColorTokens, TextStyles, ThemeData factory
    spacing.dart                     # spacing/radius constants
  models/
    recording.dart                   # immutable Recording + JSON sidecar (de)ser
    audio_source.dart                # AudioSource value type + kind enum
    recorder_state.dart              # RecorderState enum
    setup_problem.dart               # Enum of detectable problems (banner triggers)
  services/
    paths_service.dart               # app-support / recordings dirs
    binary_detector_service.dart     # Locate ffmpeg / whisper-cli on PATH
    audio_devices_service.dart       # Parse `ffmpeg -list_devices` output
    recorder_service.dart            # Start/stop ffmpeg, expose state stream
    transcriber_service.dart         # Run whisper-cli on a WAV, parse output
    library_service.dart             # CRUD + index of saved recordings
    settings_service.dart            # Persisted user settings JSON
  screens/
    record/
      record_screen.dart             # Top-level, holds RecorderService
      record_button.dart
      waveform_strip.dart            # Live reactive bars (animated)
      source_pill.dart
      source_picker_popover.dart
    session/
      session_screen.dart            # Title, transcript, basic playback
      session_toolbar.dart           # Bottom toolbar (Delete/Export/Copy/Done)
      transcript_view.dart           # Renders paragraphs + transcribing state
    library/
      library_sheet.dart
      library_row.dart
    settings/
      settings_sheet.dart
      advanced_settings_view.dart
  widgets/
    soft_card.dart                   # White card with warm shadow
    pill.dart                        # Source pill / status pill
    tonal_icon_button.dart           # 28×28 header icon button
    error_banner.dart                # Reusable warm banner on RecordScreen
test/
  models/
    recording_test.dart
    audio_source_test.dart
  services/
    paths_service_test.dart
    binary_detector_service_test.dart
    audio_devices_service_test.dart
    recorder_service_test.dart
    transcriber_service_test.dart
    library_service_test.dart
    settings_service_test.dart
  widgets/
    record_button_test.dart
    source_pill_test.dart
    error_banner_test.dart
  screens/
    record_screen_test.dart
    session_screen_test.dart
```

The current `lib/main.dart` is deleted in Task 22 (the final wiring task). Everything before that runs alongside the existing app — they coexist.

---

## Conventions

- All services accept their subprocess factory via constructor injection (typedef `ProcessSpawner`) so unit tests can substitute a fake. Default factory uses `Process.start` / `Process.run`.
- All filesystem services accept their root directory via constructor — tests use `Directory.systemTemp.createTemp()`.
- Material 3 + custom `ColorScheme`. We do not extend `ThemeExtension`; tokens live as plain `static const` on `ColorTokens` / `TextStyles` for IDE-discoverability.
- Tests run with `flutter test`. Each task commits independently with conventional-commit messages.

---

## Task 1: Add dependencies and tighten lints

**Files:**
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Add `path_provider` to dependencies**

Open `pubspec.yaml`. Under `dependencies:`, after the `cupertino_icons` line, add:

```yaml
  path_provider: ^2.1.4
```

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: `Got dependencies!` (or `Resolving dependencies...` followed by no errors).

- [ ] **Step 3: Enable stricter lints**

Replace the entire `linter:` block in `analysis_options.yaml` with:

```yaml
linter:
  rules:
    always_declare_return_types: true
    avoid_print: true
    prefer_single_quotes: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    require_trailing_commas: true
    sort_constructors_first: true
    unawaited_futures: true
    use_super_parameters: true
```

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: Analyzer flags violations in the current `lib/main.dart` (that's fine — we delete that file in Task 22). It must NOT crash; warnings are acceptable.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml
git commit -m "chore: add path_provider and tighten lints"
```

---

## Task 2: Color tokens

**Files:**
- Create: `lib/app/theme.dart`
- Create: `lib/app/spacing.dart`
- Test: `test/app/theme_test.dart`

- [ ] **Step 1: Create spacing constants**

Create `lib/app/spacing.dart`:

```dart
/// Layout spacing tokens. Multiples of 4 with a few semantic aliases.
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

class Radii {
  Radii._();

  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double pill = 999;
}
```

- [ ] **Step 2: Write the color tokens test**

Create `test/app/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';

void main() {
  test('ColorTokens are warm and never pure black', () {
    expect(ColorTokens.ink, isNot(equals(Colors.black)));
    expect(ColorTokens.ink.r, greaterThan(0.1));
  });

  test('AppTheme exposes a material 3 light theme using cream surface', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, ColorTokens.cream);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/app/theme_test.dart`
Expected: FAIL — file `lib/app/theme.dart` not found.

- [ ] **Step 4: Implement theme.dart**

Create `lib/app/theme.dart`:

```dart
import 'package:flutter/material.dart';

/// Warm-minimalist palette from spec section 2.
/// No pure black, no harsh grays. Accent is reserved for the record action.
class ColorTokens {
  ColorTokens._();

  static const Color cream = Color(0xFFFBF5EC);
  static const Color cream2 = Color(0xFFF4ECDE);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFECDFCF);
  static const Color lineSoft = Color(0xFFF4ECDE);
  static const Color ink = Color(0xFF2A1F17);
  static const Color inkSoft = Color(0xFF6B5B4A);
  static const Color inkFaint = Color(0xFFA5957F);
  static const Color accent = Color(0xFFD96A3A);
  static const Color accentDeep = Color(0xFFB85428);
  static const Color accentSoft = Color(0xFFF7E5D8);
  static const Color record = Color(0xFFC0432A);
  static const Color success = Color(0xFF4A7C4D);
  static const Color danger = Color(0xFFB3261E);
}

/// Typography roles from spec section 2.
class AppTextStyles {
  AppTextStyles._();

  // Serif family fallback chain. New York is system-provided on recent macOS;
  // Georgia is the universal fallback.
  static const String _serif = 'New York';
  static const List<String> _serifFallback = <String>['Georgia', 'serif'];

  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    color: ColorTokens.ink,
  );

  static const TextStyle sessionTitle = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: ColorTokens.ink,
  );

  static const TextStyle uiTitle = TextStyle(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: ColorTokens.ink,
  );

  static const TextStyle transcript = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 15,
    height: 1.55,
    color: Color(0xFF3A2E24),
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: ColorTokens.ink,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: ColorTokens.inkSoft,
    letterSpacing: 1.32, // 0.12em at 11px
  );

  static const TextStyle timer = TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: <String>['ui-monospace', 'monospace'],
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w300,
    color: ColorTokens.ink,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    letterSpacing: 1.5,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: <String>['ui-monospace', 'monospace'],
    fontSize: 11,
    color: ColorTokens.inkSoft,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: ColorTokens.accent,
      brightness: Brightness.light,
      surface: ColorTokens.paper,
      onSurface: ColorTokens.ink,
      primary: ColorTokens.ink,
      onPrimary: ColorTokens.cream,
      secondary: ColorTokens.accent,
      onSecondary: Colors.white,
      error: ColorTokens.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ColorTokens.cream,
      textTheme: const TextTheme(
        displayMedium: AppTextStyles.display,
        titleLarge: AppTextStyles.sessionTitle,
        titleMedium: AppTextStyles.uiTitle,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.meta,
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/app/theme_test.dart`
Expected: PASS (both tests).

- [ ] **Step 6: Commit**

```bash
git add lib/app/ test/app/
git commit -m "feat(theme): add warm-minimalist color and typography tokens"
```

---

## Task 3: Reusable widgets

**Files:**
- Create: `lib/widgets/soft_card.dart`
- Create: `lib/widgets/pill.dart`
- Create: `lib/widgets/tonal_icon_button.dart`
- Test: `test/widgets/soft_card_test.dart`
- Test: `test/widgets/pill_test.dart`

- [ ] **Step 1: Write SoftCard test**

Create `test/widgets/soft_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/widgets/soft_card.dart';

void main() {
  testWidgets('SoftCard renders child on paper surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SoftCard(child: Text('hello')),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    final container = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SoftCard),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, ColorTokens.paper);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/widgets/soft_card_test.dart`
Expected: FAIL — `lib/widgets/soft_card.dart` not found.

- [ ] **Step 3: Implement SoftCard**

Create `lib/widgets/soft_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';

/// White card with a warm shadow. The canonical container for content
/// resting on the cream window background.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.radius = Radii.lg,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColorTokens.paper,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F3C2814), // rgba(60,40,20,.06)
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
```

- [ ] **Step 4: Run SoftCard test — should pass**

Run: `flutter test test/widgets/soft_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Write Pill test**

Create `test/widgets/pill_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/widgets/pill.dart';

void main() {
  testWidgets('Pill shows label and dot, is tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Pill(
            label: 'System audio',
            dotColor: ColorTokens.accent,
            trailing: const Icon(Icons.arrow_drop_down, size: 12),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('System audio'), findsOneWidget);
    await tester.tap(find.byType(Pill));
    expect(taps, 1);
  });
}
```

- [ ] **Step 6: Run to confirm failure**

Run: `flutter test test/widgets/pill_test.dart`
Expected: FAIL — `pill.dart` not found.

- [ ] **Step 7: Implement Pill**

Create `lib/widgets/pill.dart`:

```dart
import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';

/// Rounded pill used for the source picker trigger and live-state badges.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    this.dotColor,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String label;
  final Color? dotColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (dotColor != null) ...<Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Spacing.sm),
      ],
      Text(label, style: const TextStyle(fontSize: 11, color: ColorTokens.ink)),
      if (trailing != null) ...<Widget>[
        const SizedBox(width: Spacing.sm),
        DefaultTextStyle.merge(
          style: const TextStyle(color: ColorTokens.inkFaint, fontSize: 9),
          child: trailing!,
        ),
      ],
    ];

    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: ColorTokens.paper,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F3C2814),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: 6,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

    if (onTap == null) return pill;

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.pill),
      onTap: onTap,
      child: pill,
    );
  }
}
```

- [ ] **Step 8: Implement TonalIconButton (no test — pure styling wrapper)**

Create `lib/widgets/tonal_icon_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';

/// 28×28 hoverable icon button used in screen headers.
class TonalIconButton extends StatelessWidget {
  const TonalIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onPressed,
          hoverColor: const Color(0x0A000000),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: onPressed == null
                  ? ColorTokens.inkFaint
                  : ColorTokens.inkSoft,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
```

- [ ] **Step 9: Run all widget tests**

Run: `flutter test test/widgets/`
Expected: 2 tests PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/widgets/ test/widgets/
git commit -m "feat(widgets): add SoftCard, Pill, TonalIconButton"
```

---

## Task 4: Core models

**Files:**
- Create: `lib/models/recorder_state.dart`
- Create: `lib/models/audio_source.dart`
- Create: `lib/models/recording.dart`
- Create: `lib/models/setup_problem.dart`
- Test: `test/models/audio_source_test.dart`
- Test: `test/models/recording_test.dart`

- [ ] **Step 1: Write AudioSource test**

Create `test/models/audio_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/audio_source.dart';

void main() {
  test('AudioSource.system identifies BlackHole-like inputs by name', () {
    final src = AudioSource(
      name: 'BlackHole 2ch',
      avFoundationIndex: 1,
      kind: AudioSourceKind.systemOutput,
    );
    expect(src.kind, AudioSourceKind.systemOutput);
    expect(src.displayName, 'BlackHole 2ch');
  });

  test('AudioSource equality is value-based', () {
    final a = AudioSource(
      name: 'MacBook Pro Microphone',
      avFoundationIndex: 2,
      kind: AudioSourceKind.microphone,
    );
    final b = AudioSource(
      name: 'MacBook Pro Microphone',
      avFoundationIndex: 2,
      kind: AudioSourceKind.microphone,
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/models/audio_source_test.dart`
Expected: FAIL — `audio_source.dart` not found.

- [ ] **Step 3: Implement RecorderState**

Create `lib/models/recorder_state.dart`:

```dart
/// High-level state of the recorder, used to drive the record screen UI.
enum RecorderState { idle, recording, stopping, transcribing }
```

- [ ] **Step 4: Implement AudioSource**

Create `lib/models/audio_source.dart`:

```dart
enum AudioSourceKind { systemOutput, microphone, unknown }

/// One AVFoundation audio input device.
class AudioSource {
  const AudioSource({
    required this.name,
    required this.avFoundationIndex,
    required this.kind,
  });

  final String name;
  final int avFoundationIndex;
  final AudioSourceKind kind;

  String get displayName => name;

  /// Classify a device by its name. BlackHole is the only virtual capture
  /// device most users will encounter; everything else is treated as a
  /// physical mic unless it's clearly an aggregate.
  static AudioSourceKind classify(String name) {
    final n = name.toLowerCase();
    if (n.contains('blackhole') ||
        n.contains('soundflower') ||
        n.contains('loopback') ||
        n.contains('multi-output')) {
      return AudioSourceKind.systemOutput;
    }
    if (n.contains('microphone') ||
        n.contains('mic') ||
        n.contains('cast') ||
        n.contains('audio')) {
      return AudioSourceKind.microphone;
    }
    return AudioSourceKind.unknown;
  }

  @override
  bool operator ==(Object other) {
    return other is AudioSource &&
        other.name == name &&
        other.avFoundationIndex == avFoundationIndex &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(name, avFoundationIndex, kind);
}
```

- [ ] **Step 5: Run AudioSource test**

Run: `flutter test test/models/audio_source_test.dart`
Expected: PASS.

- [ ] **Step 6: Write Recording test**

Create `test/models/recording_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/recording.dart';

void main() {
  test('Recording serializes to and from JSON', () {
    final r = Recording(
      id: 'rec_abc',
      title: 'Product sync',
      createdAt: DateTime.parse('2026-05-21T14:14:00.000Z'),
      durationSeconds: 42,
      wavPath: '/tmp/rec_abc.wav',
      sourceName: 'BlackHole 2ch',
      transcript: 'So the key insight here…',
    );

    final json = r.toJson();
    final round = Recording.fromJson(json);

    expect(round, equals(r));
  });

  test('Recording.untitled derives a title from first sentence of transcript', () {
    final t = Recording.deriveTitle(
      'So the key insight here is that BlackHole gives us a virtual cable. '
      'Then the next step is to wire it up.',
    );
    expect(t, 'So the key insight here is that BlackHole gives us a virtual cable.');
  });

  test('Recording.deriveTitle truncates a long single-sentence transcript', () {
    final long = 'a' * 200;
    final t = Recording.deriveTitle(long);
    expect(t.length, lessThanOrEqualTo(63)); // 60 + "…"
    expect(t, endsWith('…'));
  });

  test('Recording.deriveTitle returns empty when transcript is empty', () {
    expect(Recording.deriveTitle(''), '');
    expect(Recording.deriveTitle('   '), '');
  });
}
```

- [ ] **Step 7: Run to confirm failure**

Run: `flutter test test/models/recording_test.dart`
Expected: FAIL — `recording.dart` not found.

- [ ] **Step 8: Implement Recording**

Create `lib/models/recording.dart`:

```dart
/// An immutable record of one completed recording session.
class Recording {
  const Recording({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationSeconds,
    required this.wavPath,
    required this.sourceName,
    required this.transcript,
  });

  /// Stable id (used as the WAV / sidecar filename stem).
  final String id;

  /// Editable title. Auto-derived from transcript if user hasn't named it.
  final String title;

  final DateTime createdAt;
  final int durationSeconds;
  final String wavPath;
  final String sourceName;
  final String transcript;

  Recording copyWith({
    String? title,
    String? transcript,
    int? durationSeconds,
  }) {
    return Recording(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      wavPath: wavPath,
      sourceName: sourceName,
      transcript: transcript ?? this.transcript,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'wavPath': wavPath,
        'sourceName': sourceName,
        'transcript': transcript,
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        durationSeconds: json['durationSeconds'] as int,
        wavPath: json['wavPath'] as String,
        sourceName: json['sourceName'] as String,
        transcript: json['transcript'] as String,
      );

  /// Derive a human title from the first sentence of a transcript.
  /// Returns at most 60 chars, plus an ellipsis if it had to truncate.
  static String deriveTitle(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return '';
    // Sentence boundary heuristic. Good enough for English voice prompts.
    final endMatch = RegExp(r'[.!?]\s').firstMatch(trimmed);
    String candidate;
    if (endMatch != null) {
      candidate = trimmed.substring(0, endMatch.end - 1);
    } else {
      candidate = trimmed;
    }
    if (candidate.length > 60) {
      candidate = '${candidate.substring(0, 60).trimRight()}…';
    }
    return candidate;
  }

  @override
  bool operator ==(Object other) {
    return other is Recording &&
        other.id == id &&
        other.title == title &&
        other.createdAt == createdAt &&
        other.durationSeconds == durationSeconds &&
        other.wavPath == wavPath &&
        other.sourceName == sourceName &&
        other.transcript == transcript;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        createdAt,
        durationSeconds,
        wavPath,
        sourceName,
        transcript,
      );
}
```

- [ ] **Step 9: Implement SetupProblem**

Create `lib/models/setup_problem.dart`:

```dart
/// Conditions that block recording and surface as the warm error banner.
/// Each variant has user-facing copy and a primary action label.
enum SetupProblem {
  ffmpegNotFound,
  whisperNotFound,
  modelNotFound,
  noSystemAudioDevice,
  microphonePermissionDenied,
}

extension SetupProblemCopy on SetupProblem {
  String get title {
    switch (this) {
      case SetupProblem.ffmpegNotFound:
        return 'FFmpeg not found';
      case SetupProblem.whisperNotFound:
        return 'whisper-cli not found';
      case SetupProblem.modelNotFound:
        return 'Speech model not found';
      case SetupProblem.noSystemAudioDevice:
        return 'No system audio device detected';
      case SetupProblem.microphonePermissionDenied:
        return 'Transcripter needs microphone access';
    }
  }

  String get description {
    switch (this) {
      case SetupProblem.ffmpegNotFound:
        return 'Install FFmpeg with Homebrew or set the path in Settings → Advanced.';
      case SetupProblem.whisperNotFound:
        return 'Install whisper-cpp with Homebrew or set the path in Settings → Advanced.';
      case SetupProblem.modelNotFound:
        return 'Point Settings → Advanced at a downloaded ggml model file.';
      case SetupProblem.noSystemAudioDevice:
        return 'Install BlackHole 2ch to capture system audio, or pick a microphone instead.';
      case SetupProblem.microphonePermissionDenied:
        return "macOS treats BlackHole as a microphone. Allow access in System Settings, then come back — we'll detect it automatically.";
    }
  }

  String get actionLabel {
    switch (this) {
      case SetupProblem.ffmpegNotFound:
      case SetupProblem.whisperNotFound:
      case SetupProblem.modelNotFound:
        return 'Open Settings →';
      case SetupProblem.noSystemAudioDevice:
        return 'See setup help →';
      case SetupProblem.microphonePermissionDenied:
        return 'Open System Settings →';
    }
  }
}
```

- [ ] **Step 10: Run all model tests**

Run: `flutter test test/models/`
Expected: All tests PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/models/ test/models/
git commit -m "feat(models): add Recording, AudioSource, RecorderState, SetupProblem"
```

---

## Task 5: PathsService

**Files:**
- Create: `lib/services/paths_service.dart`
- Test: `test/services/paths_service_test.dart`

- [ ] **Step 1: Write PathsService test**

Create `test/services/paths_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/paths_service.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('transcripter_paths_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('recordingsDir is created on first access', () async {
    final svc = PathsService(appSupportRoot: tempRoot);
    final dir = await svc.recordingsDir();
    expect(dir.existsSync(), isTrue);
    expect(dir.path, endsWith('recordings'));
  });

  test('wavPathFor produces a unique path for an id', () async {
    final svc = PathsService(appSupportRoot: tempRoot);
    final p1 = await svc.wavPathFor('rec_a');
    final p2 = await svc.wavPathFor('rec_b');
    expect(p1, isNot(equals(p2)));
    expect(p1, endsWith('rec_a.wav'));
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/paths_service_test.dart`
Expected: FAIL — `paths_service.dart` not found.

- [ ] **Step 3: Implement PathsService**

Create `lib/services/paths_service.dart`:

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Owner of all filesystem locations Transcripter reads or writes.
/// Inject `appSupportRoot` in tests; defaults to the platform's
/// Application Support directory.
class PathsService {
  PathsService({Directory? appSupportRoot}) : _override = appSupportRoot;

  final Directory? _override;

  Future<Directory> _root() async {
    if (_override != null) return _override;
    final dir = await getApplicationSupportDirectory();
    return dir;
  }

  Future<Directory> recordingsDir() async {
    final root = await _root();
    final dir = Directory('${root.path}/recordings');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> libraryIndexDir() async {
    final root = await _root();
    final dir = Directory('${root.path}/library');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> settingsFile() async {
    final root = await _root();
    return File('${root.path}/settings.json');
  }

  Future<String> wavPathFor(String id) async {
    final dir = await recordingsDir();
    return '${dir.path}/$id.wav';
  }

  Future<String> sidecarPathFor(String id) async {
    final dir = await recordingsDir();
    return '${dir.path}/$id.json';
  }
}
```

- [ ] **Step 4: Run PathsService test**

Run: `flutter test test/services/paths_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/paths_service.dart test/services/paths_service_test.dart
git commit -m "feat(services): add PathsService for app-support directories"
```

---

## Task 6: BinaryDetectorService

**Files:**
- Create: `lib/services/binary_detector_service.dart`
- Test: `test/services/binary_detector_service_test.dart`

- [ ] **Step 1: Write detector test**

Create `test/services/binary_detector_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/binary_detector_service.dart';

void main() {
  late Directory tempBin;

  setUp(() async {
    tempBin = await Directory.systemTemp.createTemp('bin_detector_');
  });

  tearDown(() async {
    if (tempBin.existsSync()) await tempBin.delete(recursive: true);
  });

  test('locate returns the first candidate that exists', () async {
    final present = File('${tempBin.path}/ffmpeg');
    await present.writeAsString('#!/bin/sh\n');
    final svc = BinaryDetectorService(
      candidates: <String>[
        '/nope/ffmpeg',
        present.path,
      ],
    );
    expect(await svc.locate('ffmpeg'), present.path);
  });

  test('locate returns null when nothing matches', () async {
    final svc = BinaryDetectorService(candidates: const <String>['/nope']);
    expect(await svc.locate('ffmpeg'), isNull);
  });

  test('defaultCandidatesFor includes both Homebrew prefixes', () {
    final candidates = BinaryDetectorService.defaultCandidatesFor('ffmpeg');
    expect(candidates, contains('/opt/homebrew/bin/ffmpeg'));
    expect(candidates, contains('/usr/local/bin/ffmpeg'));
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/binary_detector_service_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement BinaryDetectorService**

Create `lib/services/binary_detector_service.dart`:

```dart
import 'dart:io';

/// Finds CLI binaries (ffmpeg, whisper-cli) without relying on the shell
/// PATH inheritance behavior of GUI apps (which is unreliable on macOS).
/// Looks at well-known absolute paths in order.
class BinaryDetectorService {
  BinaryDetectorService({required this.candidates});

  final List<String> candidates;

  /// Returns the first candidate path that exists, or null.
  Future<String?> locate(String _name) async {
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  /// Default candidate list for a given binary on macOS.
  /// Ordered: user override → Apple Silicon Homebrew → Intel Homebrew → /usr/bin.
  static List<String> defaultCandidatesFor(String name) {
    return <String>[
      '/opt/homebrew/bin/$name',
      '/usr/local/bin/$name',
      '/usr/bin/$name',
    ];
  }
}
```

- [ ] **Step 4: Run BinaryDetectorService test**

Run: `flutter test test/services/binary_detector_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/binary_detector_service.dart test/services/binary_detector_service_test.dart
git commit -m "feat(services): add BinaryDetectorService for ffmpeg/whisper lookup"
```

---

## Task 7: AudioDevicesService

**Files:**
- Create: `lib/services/audio_devices_service.dart`
- Test: `test/services/audio_devices_service_test.dart`

- [ ] **Step 1: Write parser test using captured ffmpeg output**

Create `test/services/audio_devices_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/services/audio_devices_service.dart';

const String _sampleOutput = '''
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
[AVFoundation indev @ 0xa17400140] AVFoundation video devices:
[AVFoundation indev @ 0xa17400140] [0] FaceTime HD Camera
[AVFoundation indev @ 0xa17400140] [1] papp's iPhone 16 Camera
[AVFoundation indev @ 0xa17400140] AVFoundation audio devices:
[AVFoundation indev @ 0xa17400140] [0] CalDigit Thunderbolt 3 Audio
[AVFoundation indev @ 0xa17400140] [1] BlackHole 2ch
[AVFoundation indev @ 0xa17400140] [2] MacBook Pro Microphone
[AVFoundation indev @ 0xa17400140] [3] HyperX Quadcast
[in#0 @ 0xa17400000] Error opening input: Input/output error
''';

void main() {
  test('parses audio devices, ignores video block', () {
    final devices = AudioDevicesService.parseList(_sampleOutput);
    expect(devices, hasLength(4));
    expect(devices[1].name, 'BlackHole 2ch');
    expect(devices[1].avFoundationIndex, 1);
    expect(devices[1].kind, AudioSourceKind.systemOutput);
  });

  test('classifies microphones correctly', () {
    final devices = AudioDevicesService.parseList(_sampleOutput);
    expect(devices[2].kind, AudioSourceKind.microphone);
  });

  test('returns empty list when no audio block present', () {
    final devices = AudioDevicesService.parseList(
      '[AVFoundation indev @ 0x0] AVFoundation video devices:\n'
      '[AVFoundation indev @ 0x0] [0] FaceTime HD Camera\n',
    );
    expect(devices, isEmpty);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/audio_devices_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement AudioDevicesService**

Create `lib/services/audio_devices_service.dart`:

```dart
import 'dart:io';

import '../models/audio_source.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Enumerates AVFoundation audio capture devices by parsing
/// `ffmpeg -f avfoundation -list_devices true -i ""` output.
class AudioDevicesService {
  AudioDevicesService({
    required this.ffmpegPath,
    ProcessRunner? runner,
  }) : _run = runner ?? Process.run;

  final String ffmpegPath;
  final ProcessRunner _run;

  Future<List<AudioSource>> list() async {
    // ffmpeg prints to stderr and exits non-zero — both are expected.
    final result = await _run(ffmpegPath, const <String>[
      '-f',
      'avfoundation',
      '-list_devices',
      'true',
      '-i',
      '',
    ]);
    final combined =
        '${result.stdout?.toString() ?? ''}\n${result.stderr?.toString() ?? ''}';
    return parseList(combined);
  }

  /// Pure parser, exposed for unit testing.
  static List<AudioSource> parseList(String output) {
    final lines = output.split('\n');
    bool inAudioBlock = false;
    final entries = <AudioSource>[];
    final entryPattern = RegExp(r'\[\d+\]\s+(.+)$');

    for (final raw in lines) {
      final line = raw.trim();
      if (line.contains('AVFoundation audio devices')) {
        inAudioBlock = true;
        continue;
      }
      if (line.contains('AVFoundation video devices')) {
        inAudioBlock = false;
        continue;
      }
      if (!inAudioBlock) continue;

      // Lines look like:
      // [AVFoundation indev @ 0x…] [1] BlackHole 2ch
      final bracketIdx = line.indexOf('] [');
      if (bracketIdx < 0) continue;
      final tail = line.substring(bracketIdx + 2); // "[1] BlackHole 2ch"
      final match = entryPattern.firstMatch(tail);
      if (match == null) continue;
      final indexStr = RegExp(r'\[(\d+)\]').firstMatch(tail)?.group(1);
      if (indexStr == null) continue;
      final name = match.group(1)!.trim();
      entries.add(AudioSource(
        name: name,
        avFoundationIndex: int.parse(indexStr),
        kind: AudioSource.classify(name),
      ));
    }

    return entries;
  }
}
```

- [ ] **Step 4: Run AudioDevicesService test**

Run: `flutter test test/services/audio_devices_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio_devices_service.dart test/services/audio_devices_service_test.dart
git commit -m "feat(services): add AudioDevicesService with avfoundation list parser"
```

---

## Task 8: RecorderService

**Files:**
- Create: `lib/services/recorder_service.dart`
- Test: `test/services/recorder_service_test.dart`

- [ ] **Step 1: Write RecorderService test using a fake spawner**

Create `test/services/recorder_service_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/models/recorder_state.dart';
import 'package:transcripter/services/recorder_service.dart';

class _FakeProcess implements Process {
  final int _pid = 4242;
  final Completer<int> _exit = Completer<int>();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => _pid;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  bool killCalled = false;
  ProcessSignal? lastSignal;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCalled = true;
    lastSignal = signal;
    _exit.complete(signal == ProcessSignal.sigint ? 0 : 130);
    return true;
  }
}

void main() {
  test('start emits recording state and resolves device index in ffmpeg args', () async {
    late List<String> capturedArgs;
    final fake = _FakeProcess();
    final svc = RecorderService(
      ffmpegPath: '/fake/ffmpeg',
      spawner: (executable, args) async {
        capturedArgs = args;
        return fake;
      },
    );

    final states = <RecorderState>[];
    final sub = svc.state.listen(states.add);

    await svc.start(
      source: const AudioSource(
        name: 'BlackHole 2ch',
        avFoundationIndex: 1,
        kind: AudioSourceKind.systemOutput,
      ),
      outputWavPath: '/tmp/r.wav',
    );

    expect(svc.currentState, RecorderState.recording);
    expect(capturedArgs.contains(':1'), isTrue);
    expect(capturedArgs.contains('16000'), isTrue);
    expect(capturedArgs.last, '/tmp/r.wav');
    await sub.cancel();
    expect(states.last, RecorderState.recording);
  });

  test('stop sends SIGINT and transitions through stopping to idle', () async {
    final fake = _FakeProcess();
    final svc = RecorderService(
      ffmpegPath: '/fake/ffmpeg',
      spawner: (_, __) async => fake,
    );

    await svc.start(
      source: const AudioSource(
        name: 'BlackHole 2ch',
        avFoundationIndex: 1,
        kind: AudioSourceKind.systemOutput,
      ),
      outputWavPath: '/tmp/r.wav',
    );

    await svc.stop();
    expect(fake.killCalled, isTrue);
    expect(fake.lastSignal, ProcessSignal.sigint);
    expect(svc.currentState, RecorderState.idle);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/recorder_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement RecorderService**

Create `lib/services/recorder_service.dart`:

```dart
import 'dart:async';
import 'dart:io';

import '../models/audio_source.dart';
import '../models/recorder_state.dart';

typedef ProcessSpawner = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Wraps the FFmpeg subprocess that captures audio to a WAV. Exposes the
/// current state and the elapsed time of an active recording.
class RecorderService {
  RecorderService({
    required this.ffmpegPath,
    ProcessSpawner? spawner,
  }) : _spawn = spawner ?? Process.start;

  final String ffmpegPath;
  final ProcessSpawner _spawn;

  final StreamController<RecorderState> _stateCtl =
      StreamController<RecorderState>.broadcast();
  RecorderState _state = RecorderState.idle;
  Process? _process;
  DateTime? _startedAt;

  Stream<RecorderState> get state => _stateCtl.stream;
  RecorderState get currentState => _state;
  DateTime? get startedAt => _startedAt;

  /// Begins recording. Returns once ffmpeg has been spawned.
  Future<void> start({
    required AudioSource source,
    required String outputWavPath,
  }) async {
    if (_state != RecorderState.idle) {
      throw StateError('Cannot start recorder in state $_state');
    }
    final outFile = File(outputWavPath);
    if (!outFile.parent.existsSync()) {
      await outFile.parent.create(recursive: true);
    }
    final process = await _spawn(ffmpegPath, <String>[
      '-y',
      '-f',
      'avfoundation',
      '-i',
      ':${source.avFoundationIndex}',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'pcm_s16le',
      outputWavPath,
    ]);
    _process = process;
    _startedAt = DateTime.now();
    _setState(RecorderState.recording);

    // Detach a watcher so unexpected exits flip us back to idle.
    unawaited(process.exitCode.then((_) {
      if (_state == RecorderState.recording) {
        _setState(RecorderState.idle);
        _process = null;
        _startedAt = null;
      }
    }));
  }

  /// Stops recording cleanly. SIGINT → SIGTERM → SIGKILL escalation.
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _setState(RecorderState.stopping);

    process.kill(ProcessSignal.sigint);
    try {
      await process.exitCode.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 2));
      }
    }

    _process = null;
    _startedAt = null;
    _setState(RecorderState.idle);
  }

  Duration elapsed() {
    final started = _startedAt;
    if (started == null) return Duration.zero;
    return DateTime.now().difference(started);
  }

  void dispose() {
    _process?.kill(ProcessSignal.sigint);
    _stateCtl.close();
  }

  void _setState(RecorderState s) {
    _state = s;
    _stateCtl.add(s);
  }
}
```

- [ ] **Step 4: Run RecorderService test**

Run: `flutter test test/services/recorder_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/recorder_service.dart test/services/recorder_service_test.dart
git commit -m "feat(services): add RecorderService wrapping ffmpeg avfoundation capture"
```

---

## Task 9: TranscriberService

**Files:**
- Create: `lib/services/transcriber_service.dart`
- Test: `test/services/transcriber_service_test.dart`

- [ ] **Step 1: Write transcriber test using fake runner**

Create `test/services/transcriber_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/transcriber_service.dart';

void main() {
  test('transcribe returns whisper stdout as plain text on exit 0', () async {
    final svc = TranscriberService(
      whisperPath: '/fake/whisper-cli',
      runner: (_, __) async => ProcessResult(
        1,
        0,
        '[00:00.000 --> 00:03.000]  Hello world this is a test.\n',
        '',
      ),
    );

    final out = await svc.transcribe(
      wavPath: '/tmp/x.wav',
      modelPath: '/tmp/model.bin',
      language: 'en',
    );

    expect(out.text, contains('Hello world this is a test.'));
    expect(out.exitCode, 0);
  });

  test('transcribe throws TranscriberFailed on non-zero exit', () async {
    final svc = TranscriberService(
      whisperPath: '/fake/whisper-cli',
      runner: (_, __) async => ProcessResult(1, 2, '', 'oh no'),
    );

    expect(
      () => svc.transcribe(
        wavPath: '/tmp/x.wav',
        modelPath: '/tmp/model.bin',
        language: 'en',
      ),
      throwsA(isA<TranscriberFailed>()),
    );
  });

  test('parseTimestampedOutput strips brackets to plain prose', () {
    const raw =
        '[00:00.000 --> 00:03.000]  Hello world.\n'
        '[00:03.000 --> 00:06.500]  This is a second sentence.\n';
    final plain = TranscriberService.parseTimestampedOutput(raw);
    expect(plain, 'Hello world. This is a second sentence.');
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/transcriber_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement TranscriberService**

Create `lib/services/transcriber_service.dart`:

```dart
import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class TranscriptionResult {
  const TranscriptionResult({required this.text, required this.exitCode});

  final String text;
  final int exitCode;
}

class TranscriberFailed implements Exception {
  TranscriberFailed(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;

  @override
  String toString() =>
      'whisper-cli failed with exit code $exitCode:\n$stderr';
}

/// Runs whisper.cpp (`whisper-cli`) on a WAV file and returns the transcript.
class TranscriberService {
  TranscriberService({
    required this.whisperPath,
    ProcessRunner? runner,
  }) : _run = runner ?? Process.run;

  final String whisperPath;
  final ProcessRunner _run;

  Future<TranscriptionResult> transcribe({
    required String wavPath,
    required String modelPath,
    required String language,
  }) async {
    final args = <String>[
      '-m',
      modelPath,
      '-f',
      wavPath,
      '-np', // no progress prints — keeps stdout transcript-only
      if (language.isNotEmpty) ...<String>['-l', language],
    ];
    final result = await _run(whisperPath, args);
    if (result.exitCode != 0) {
      throw TranscriberFailed(
        result.exitCode,
        result.stderr?.toString() ?? '',
      );
    }
    final raw = result.stdout?.toString() ?? '';
    return TranscriptionResult(
      text: parseTimestampedOutput(raw),
      exitCode: result.exitCode,
    );
  }

  /// whisper-cli (without `-otxt`) prints lines like
  ///   `[00:00.000 --> 00:03.000]  Hello.`
  /// Strip the timestamps and join into prose.
  static String parseTimestampedOutput(String raw) {
    final lineRe = RegExp(r'^\[\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}\.\d{3}\]\s*(.*)$');
    final out = <String>[];
    for (final line in raw.split('\n')) {
      final m = lineRe.firstMatch(line.trim());
      if (m != null) {
        final segment = m.group(1)!.trim();
        if (segment.isNotEmpty) out.add(segment);
      }
    }
    return out.join(' ');
  }
}
```

- [ ] **Step 4: Run TranscriberService test**

Run: `flutter test test/services/transcriber_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/transcriber_service.dart test/services/transcriber_service_test.dart
git commit -m "feat(services): add TranscriberService with whisper-cli wrapper"
```

---

## Task 10: LibraryService

**Files:**
- Create: `lib/services/library_service.dart`
- Test: `test/services/library_service_test.dart`

- [ ] **Step 1: Write LibraryService test**

Create `test/services/library_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/models/recording.dart';
import 'package:transcripter/services/library_service.dart';
import 'package:transcripter/services/paths_service.dart';

void main() {
  late Directory tempRoot;
  late LibraryService lib;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('library_svc_');
    lib = LibraryService(paths: PathsService(appSupportRoot: tempRoot));
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  Recording sample(String id, {String title = 'Untitled'}) => Recording(
        id: id,
        title: title,
        createdAt: DateTime.utc(2026, 5, 21, 14, 14),
        durationSeconds: 42,
        wavPath: '/tmp/$id.wav',
        sourceName: 'BlackHole 2ch',
        transcript: '',
      );

  test('save writes a sidecar file readable by list', () async {
    await lib.save(sample('rec_a', title: 'Product sync'));
    final all = await lib.list();
    expect(all, hasLength(1));
    expect(all.first.id, 'rec_a');
    expect(all.first.title, 'Product sync');
  });

  test('list returns most-recent first', () async {
    await lib.save(sample('rec_a').copyWith()); // placeholder
    final older = Recording(
      id: 'rec_a',
      title: 'A',
      createdAt: DateTime.utc(2026, 5, 19, 9, 0),
      durationSeconds: 10,
      wavPath: '/tmp/a.wav',
      sourceName: 'mic',
      transcript: '',
    );
    final newer = Recording(
      id: 'rec_b',
      title: 'B',
      createdAt: DateTime.utc(2026, 5, 20, 9, 0),
      durationSeconds: 10,
      wavPath: '/tmp/b.wav',
      sourceName: 'mic',
      transcript: '',
    );
    await lib.save(older);
    await lib.save(newer);
    final all = await lib.list();
    expect(all.map((r) => r.id).toList(), <String>['rec_b', 'rec_a']);
  });

  test('delete removes sidecar and wav', () async {
    final rec = sample('rec_x');
    // Create a fake wav alongside
    final wavFile = File(rec.wavPath);
    await wavFile.writeAsString('fake');
    await lib.save(rec.copyWith()); // ignore: avoid_redundant_argument_values
    await lib.delete(rec);
    final all = await lib.list();
    expect(all, isEmpty);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/library_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement LibraryService**

Create `lib/services/library_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import '../models/recording.dart';
import 'paths_service.dart';

/// Persists recordings as JSON sidecars next to their WAV files.
/// `list()` reads the directory and returns recordings sorted newest-first.
class LibraryService {
  LibraryService({required this.paths});

  final PathsService paths;

  Future<void> save(Recording rec) async {
    final sidecarPath = await paths.sidecarPathFor(rec.id);
    final file = File(sidecarPath);
    await file.writeAsString(jsonEncode(rec.toJson()));
  }

  Future<List<Recording>> list() async {
    final dir = await paths.recordingsDir();
    final entries = <Recording>[];
    if (!dir.existsSync()) return entries;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      try {
        final raw = await entity.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        entries.add(Recording.fromJson(json));
      } on FormatException {
        // Skip malformed sidecars; they'll be repaired on next save or
        // deleted by the user.
        continue;
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> delete(Recording rec) async {
    final wav = File(rec.wavPath);
    if (wav.existsSync()) await wav.delete();
    final sidecar = File(await paths.sidecarPathFor(rec.id));
    if (sidecar.existsSync()) await sidecar.delete();
  }
}
```

- [ ] **Step 4: Run LibraryService test**

Run: `flutter test test/services/library_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/library_service.dart test/services/library_service_test.dart
git commit -m "feat(services): add LibraryService for recording sidecars"
```

---

## Task 11: SettingsService

**Files:**
- Create: `lib/services/settings_service.dart`
- Test: `test/services/settings_service_test.dart`

- [ ] **Step 1: Write SettingsService test**

Create `test/services/settings_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/paths_service.dart';
import 'package:transcripter/services/settings_service.dart';

void main() {
  late Directory tempRoot;
  late SettingsService svc;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('settings_');
    svc = SettingsService(paths: PathsService(appSupportRoot: tempRoot));
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('load returns defaults when no file exists', () async {
    final s = await svc.load();
    expect(s.language, 'en');
    expect(s.ffmpegPathOverride, isNull);
    expect(s.preferredSourceName, isNull);
  });

  test('save then load round-trips', () async {
    await svc.save(const AppSettings(
      language: 'fr',
      ffmpegPathOverride: '/custom/ffmpeg',
      whisperPathOverride: null,
      modelPathOverride: '/custom/ggml.bin',
      preferredSourceName: 'BlackHole 2ch',
    ));
    final loaded = await svc.load();
    expect(loaded.language, 'fr');
    expect(loaded.ffmpegPathOverride, '/custom/ffmpeg');
    expect(loaded.modelPathOverride, '/custom/ggml.bin');
    expect(loaded.preferredSourceName, 'BlackHole 2ch');
  });

  test('copyWith with clearX nulls out a previously-set override', () {
    const before = AppSettings(
      language: 'en',
      ffmpegPathOverride: '/x/ffmpeg',
      whisperPathOverride: null,
      modelPathOverride: null,
      preferredSourceName: null,
    );
    final after = before.copyWith(clearFfmpegOverride: true);
    expect(after.ffmpegPathOverride, isNull);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/services/settings_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement SettingsService**

Create `lib/services/settings_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'paths_service.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.ffmpegPathOverride,
    required this.whisperPathOverride,
    required this.modelPathOverride,
    required this.preferredSourceName,
  });

  final String language;
  final String? ffmpegPathOverride;
  final String? whisperPathOverride;
  final String? modelPathOverride;
  final String? preferredSourceName;

  static const AppSettings defaults = AppSettings(
    language: 'en',
    ffmpegPathOverride: null,
    whisperPathOverride: null,
    modelPathOverride: null,
    preferredSourceName: null,
  );

  /// Returns a copy with the named fields replaced. Pass `clearX: true`
  /// for nullable fields to explicitly null them out — `value ?? this.value`
  /// can't tell "don't change" from "set to null".
  AppSettings copyWith({
    String? language,
    String? ffmpegPathOverride,
    bool clearFfmpegOverride = false,
    String? whisperPathOverride,
    bool clearWhisperOverride = false,
    String? modelPathOverride,
    bool clearModelOverride = false,
    String? preferredSourceName,
    bool clearPreferredSource = false,
  }) {
    return AppSettings(
      language: language ?? this.language,
      ffmpegPathOverride: clearFfmpegOverride
          ? null
          : (ffmpegPathOverride ?? this.ffmpegPathOverride),
      whisperPathOverride: clearWhisperOverride
          ? null
          : (whisperPathOverride ?? this.whisperPathOverride),
      modelPathOverride: clearModelOverride
          ? null
          : (modelPathOverride ?? this.modelPathOverride),
      preferredSourceName: clearPreferredSource
          ? null
          : (preferredSourceName ?? this.preferredSourceName),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'language': language,
        'ffmpegPathOverride': ffmpegPathOverride,
        'whisperPathOverride': whisperPathOverride,
        'modelPathOverride': modelPathOverride,
        'preferredSourceName': preferredSourceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        language: (json['language'] as String?) ?? defaults.language,
        ffmpegPathOverride: json['ffmpegPathOverride'] as String?,
        whisperPathOverride: json['whisperPathOverride'] as String?,
        modelPathOverride: json['modelPathOverride'] as String?,
        preferredSourceName: json['preferredSourceName'] as String?,
      );
}

class SettingsService {
  SettingsService({required this.paths});

  final PathsService paths;

  Future<AppSettings> load() async {
    final file = await paths.settingsFile();
    if (!file.existsSync()) return AppSettings.defaults;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } on FormatException {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await paths.settingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
```

- [ ] **Step 4: Run SettingsService test**

Run: `flutter test test/services/settings_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/settings_service.dart test/services/settings_service_test.dart
git commit -m "feat(services): add SettingsService with JSON persistence"
```

---

## Task 12: RecordButton widget

**Files:**
- Create: `lib/screens/record/record_button.dart`
- Test: `test/widgets/record_button_test.dart`

- [ ] **Step 1: Write the widget test**

Create `test/widgets/record_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/screens/record/record_button.dart';

void main() {
  testWidgets('RecordButton fires onTap when active', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: RecordButton(
              isRecording: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecordButton));
    expect(taps, 1);
  });

  testWidgets('RecordButton renders darker fill while recording', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: RecordButton(isRecording: true, onTap: () {}),
          ),
        ),
      ),
    );
    // No exception while painting the active state is the assertion we need
    // — the visual difference is verified by inspection.
    await tester.pumpAndSettle();
    expect(find.byType(RecordButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/widgets/record_button_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement RecordButton**

Create `lib/screens/record/record_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 96×96 circular button. Terracotta gradient when idle, dark ink when
/// recording (signals "press to stop"). Outer halo intensifies on active.
class RecordButton extends StatelessWidget {
  const RecordButton({
    required this.isRecording,
    required this.onTap,
    this.disabled = false,
    super.key,
  });

  final bool isRecording;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final fillGradient = isRecording
        ? const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: <Color>[Color(0xFF3A2E24), ColorTokens.ink],
          )
        : const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: <Color>[Color(0xFFEE8A5A), ColorTokens.accentDeep],
          );

    final shadowColor = isRecording
        ? const Color(0x59281E14) // ink shadow ~35%
        : const Color(0x52C0432A); // record shadow ~32%

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: disabled ? null : fillGradient,
          color: disabled ? ColorTokens.inkFaint : null,
          boxShadow: <BoxShadow>[
            if (!disabled)
              BoxShadow(
                color: shadowColor,
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
          ],
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xF2FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run RecordButton tests**

Run: `flutter test test/widgets/record_button_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/record/record_button.dart test/widgets/record_button_test.dart
git commit -m "feat(record): add RecordButton with idle/active visual states"
```

---

## Task 13: WaveformStrip widget

**Files:**
- Create: `lib/screens/record/waveform_strip.dart`

- [ ] **Step 1: Implement WaveformStrip**

No unit test — this is purely decorative animation; visual inspection in the smoke test (Task 25) covers it.

Create `lib/screens/record/waveform_strip.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Decorative live-looking waveform. Bars animate via a single repeating
/// AnimationController; heights are pseudo-random per bar and per tick.
class WaveformStrip extends StatefulWidget {
  const WaveformStrip({
    this.barCount = 28,
    this.height = 32,
    this.color = ColorTokens.accent,
    super.key,
  });

  final int barCount;
  final double height;
  final Color color;

  @override
  State<WaveformStrip> createState() => _WaveformStripState();
}

class _WaveformStripState extends State<WaveformStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  final math.Random _rng = math.Random(7);
  late final List<double> _phase = List<double>.generate(
    widget.barCount,
    (_) => _rng.nextDouble(),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(widget.barCount, (i) {
              final wobble = math.sin((_ctl.value * 2 * math.pi) + _phase[i] * 6.28);
              final amp = 0.3 + 0.7 * ((wobble + 1) / 2) * (0.5 + _phase[i] * 0.5);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: 2,
                  height: widget.height * amp,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.55 + 0.45 * amp),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/record/waveform_strip.dart
git commit -m "feat(record): add animated WaveformStrip"
```

---

## Task 14: SourcePill + SourcePickerPopover

**Files:**
- Create: `lib/screens/record/source_pill.dart`
- Create: `lib/screens/record/source_picker_popover.dart`
- Test: `test/widgets/source_pill_test.dart`

- [ ] **Step 1: Write SourcePill test**

Create `test/widgets/source_pill_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/screens/record/source_pill.dart';

void main() {
  testWidgets('SourcePill shows device name and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SourcePill(
              source: const AudioSource(
                name: 'BlackHole 2ch',
                avFoundationIndex: 1,
                kind: AudioSourceKind.systemOutput,
              ),
              enabled: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('BlackHole 2ch'), findsOneWidget);
    await tester.tap(find.byType(SourcePill));
    expect(taps, 1);
  });

  testWidgets('SourcePill does not invoke onTap when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SourcePill(
              source: const AudioSource(
                name: 'mic',
                avFoundationIndex: 0,
                kind: AudioSourceKind.microphone,
              ),
              enabled: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SourcePill));
    expect(taps, 0);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/widgets/source_pill_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement SourcePill**

Create `lib/screens/record/source_pill.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/audio_source.dart';
import '../../widgets/pill.dart';

class SourcePill extends StatelessWidget {
  const SourcePill({
    required this.source,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final AudioSource source;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = source.kind == AudioSourceKind.systemOutput
        ? 'System audio · ${source.name}'
        : source.name;
    return Opacity(
      opacity: enabled ? 1.0 : 0.7,
      child: Pill(
        label: label,
        dotColor: ColorTokens.accent,
        trailing: enabled ? const Icon(Icons.arrow_drop_down, size: 12) : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
```

- [ ] **Step 4: Run SourcePill tests**

Run: `flutter test test/widgets/source_pill_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Implement SourcePickerPopover**

Create `lib/screens/record/source_picker_popover.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/audio_source.dart';

/// Anchored menu shown by `showMenu` from the SourcePill. Grouped by kind.
class SourcePickerPopover {
  SourcePickerPopover._();

  /// [anchorContext] must be the BuildContext of the widget the popover
  /// should anchor below (typically the SourcePill, captured via Builder).
  static Future<AudioSource?> show({
    required BuildContext anchorContext,
    required List<AudioSource> sources,
    required AudioSource? active,
  }) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final anchorPos = anchorBox.localToGlobal(Offset.zero);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        anchorPos.dx,
        anchorPos.dy + anchorBox.size.height + 6,
        anchorBox.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    final systemOutputs =
        sources.where((s) => s.kind == AudioSourceKind.systemOutput).toList();
    final mics = sources.where((s) => s.kind != AudioSourceKind.systemOutput).toList();

    final items = <PopupMenuEntry<AudioSource>>[];
    if (systemOutputs.isNotEmpty) {
      items.add(_section('System output'));
      for (final s in systemOutputs) {
        items.add(_row(s, isActive: s == active));
      }
    }
    if (mics.isNotEmpty) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(_section('Microphones'));
      for (final s in mics) {
        items.add(_row(s, isActive: s == active));
      }
    }

    return showMenu<AudioSource>(
      context: anchorContext,
      position: position,
      color: ColorTokens.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      elevation: 16,
      items: items,
    );
  }

  static PopupMenuEntry<AudioSource> _section(String title) {
    return PopupMenuItem<AudioSource>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          color: ColorTokens.inkFaint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static PopupMenuEntry<AudioSource> _row(AudioSource s, {required bool isActive}) {
    return PopupMenuItem<AudioSource>(
      value: s,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? ColorTokens.accentSoft : ColorTokens.cream2,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              s.kind == AudioSourceKind.systemOutput ? Icons.speaker : Icons.mic,
              size: 14,
              color: ColorTokens.ink,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              s.name,
              style: const TextStyle(fontSize: 12, color: ColorTokens.ink),
            ),
          ),
          if (isActive) const Icon(Icons.check, size: 14, color: ColorTokens.accent),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/record/source_pill.dart lib/screens/record/source_picker_popover.dart test/widgets/source_pill_test.dart
git commit -m "feat(record): add SourcePill and SourcePickerPopover"
```

---

## Task 15: ErrorBanner widget

**Files:**
- Create: `lib/widgets/error_banner.dart`
- Test: `test/widgets/error_banner_test.dart`

- [ ] **Step 1: Write ErrorBanner test**

Create `test/widgets/error_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/setup_problem.dart';
import 'package:transcripter/widgets/error_banner.dart';

void main() {
  testWidgets('ErrorBanner shows problem copy and fires action', (tester) async {
    var actionTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ErrorBanner(
            problem: SetupProblem.microphonePermissionDenied,
            onAction: () => actionTaps++,
          ),
        ),
      ),
    );

    expect(find.text(SetupProblem.microphonePermissionDenied.title), findsOneWidget);
    expect(find.text(SetupProblem.microphonePermissionDenied.actionLabel), findsOneWidget);

    await tester.tap(find.text(SetupProblem.microphonePermissionDenied.actionLabel));
    expect(actionTaps, 1);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/widgets/error_banner_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement ErrorBanner**

Create `lib/widgets/error_banner.dart`:

```dart
import 'package:flutter/material.dart';

import '../app/spacing.dart';
import '../app/theme.dart';
import '../models/setup_problem.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.problem,
    required this.onAction,
    super.key,
  });

  final SetupProblem problem;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF0E8),
        border: Border.all(color: const Color(0xFFF4C8B1)),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded,
                color: ColorTokens.accentDeep, size: 18),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  problem.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  problem.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ColorTokens.inkSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onAction,
                  child: Text(
                    problem.actionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ColorTokens.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run ErrorBanner test**

Run: `flutter test test/widgets/error_banner_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/error_banner.dart test/widgets/error_banner_test.dart
git commit -m "feat(widgets): add ErrorBanner"
```

---

## Task 16: RecordScreen — idle + active

**Files:**
- Create: `lib/screens/record/record_screen.dart`
- Test: `test/screens/record_screen_test.dart`

- [ ] **Step 1: Write smoke widget test**

Create `test/screens/record_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/audio_source.dart';
import 'package:transcripter/screens/record/record_screen.dart';

void main() {
  testWidgets('RecordScreen shows brand, source pill, timer at idle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const RecordScreen.preview(
          source: AudioSource(
            name: 'BlackHole 2ch',
            avFoundationIndex: 1,
            kind: AudioSourceKind.systemOutput,
          ),
        ),
      ),
    );

    expect(find.text('Transcripter'), findsOneWidget);
    expect(find.textContaining('BlackHole 2ch'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Tap to record'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/screens/record_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement RecordScreen**

Create `lib/screens/record/record_screen.dart`:

```dart
import 'dart:async';

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
```

- [ ] **Step 4: Run RecordScreen test**

Run: `flutter test test/screens/record_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/record/record_screen.dart test/screens/record_screen_test.dart
git commit -m "feat(record): assemble RecordScreen (idle + active) with footer and header"
```

---

## Task 17: TranscriptView + SessionToolbar

**Files:**
- Create: `lib/screens/session/transcript_view.dart`
- Create: `lib/screens/session/session_toolbar.dart`

- [ ] **Step 1: Implement TranscriptView**

Create `lib/screens/session/transcript_view.dart`:

```dart
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
    // Split on blank lines first; if there are none, group every ~3 sentences.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
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
```

- [ ] **Step 2: Implement SessionToolbar**

Create `lib/screens/session/session_toolbar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';

class SessionToolbar extends StatelessWidget {
  const SessionToolbar({
    required this.onDelete,
    required this.onExport,
    required this.onCopy,
    required this.onDone,
    super.key,
  });

  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      color: ColorTokens.cream2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _btn(label: 'Delete', tertiary: true, onTap: onDelete),
          const SizedBox(width: Spacing.sm),
          _btn(label: 'Export…', onTap: onExport),
          const SizedBox(width: Spacing.sm),
          _btn(label: 'Copy text', onTap: onCopy),
          const SizedBox(width: Spacing.sm),
          _btn(label: 'Done', primary: true, onTap: onDone),
        ],
      ),
    );
  }

  Widget _btn({
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool tertiary = false,
  }) {
    final Color bg = primary
        ? ColorTokens.ink
        : tertiary
            ? Colors.transparent
            : ColorTokens.paper;
    final Color fg = primary
        ? ColorTokens.cream
        : tertiary
            ? ColorTokens.inkSoft
            : ColorTokens.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: tertiary || primary
              ? null
              : Border.all(color: ColorTokens.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/session/transcript_view.dart lib/screens/session/session_toolbar.dart
git commit -m "feat(session): add TranscriptView and SessionToolbar"
```

---

## Task 18: SessionScreen

**Files:**
- Create: `lib/screens/session/session_screen.dart`
- Test: `test/screens/session_screen_test.dart`

- [ ] **Step 1: Write SessionScreen test**

Create `test/screens/session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/app/theme.dart';
import 'package:transcripter/models/recording.dart';
import 'package:transcripter/screens/session/session_screen.dart';

void main() {
  testWidgets('SessionScreen shows title and transcript when ready', (tester) async {
    final rec = Recording(
      id: 'r1',
      title: 'Product sync',
      createdAt: DateTime(2026, 5, 21, 14, 14),
      durationSeconds: 42,
      wavPath: '/tmp/r1.wav',
      sourceName: 'BlackHole 2ch',
      transcript: 'Hello world. This is a test.',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SessionScreen(
          recording: rec,
          isTranscribing: false,
          onBack: () {},
          onDelete: () {},
          onExport: () {},
          onCopy: () {},
          onTitleChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Product sync'), findsOneWidget);
    expect(find.textContaining('Hello world'), findsOneWidget);
  });

  testWidgets('SessionScreen shows Untitled when transcribing and no title', (tester) async {
    final rec = Recording(
      id: 'r1',
      title: '',
      createdAt: DateTime(2026, 5, 21, 14, 14),
      durationSeconds: 42,
      wavPath: '/tmp/r1.wav',
      sourceName: 'BlackHole 2ch',
      transcript: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SessionScreen(
          recording: rec,
          isTranscribing: true,
          onBack: () {},
          onDelete: () {},
          onExport: () {},
          onCopy: () {},
          onTitleChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Untitled recording'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/screens/session_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement SessionScreen**

Create `lib/screens/session/session_screen.dart`:

```dart
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
  late final TextEditingController _titleCtl =
      TextEditingController(text: widget.recording.title);
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
            _Header(onBack: widget.onBack),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md, 0, Spacing.md, Spacing.md,
                ),
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.xl, Spacing.lg, Spacing.xl, Spacing.lg,
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
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.sm),
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
          TonalIconButton(icon: Icons.download_outlined, onPressed: () {}, tooltip: 'Export'),
          TonalIconButton(icon: Icons.copy_outlined, onPressed: () {}, tooltip: 'Copy'),
          TonalIconButton(icon: Icons.more_horiz, onPressed: () {}, tooltip: 'More'),
        ],
      ),
    );
  }
}

String _metaLine(Recording r) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = r.createdAt.toLocal();
  final today = DateTime.now();
  final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
  final datePart = isToday ? 'TODAY' : '${two(d.year)}-${two(d.month)}-${two(d.day)}';
  final timePart = '${two(d.hour)}:${two(d.minute)}';
  final durM = r.durationSeconds ~/ 60;
  final durS = r.durationSeconds % 60;
  return '$datePart · $timePart · ${two(durM)}:${two(durS)} · ${r.sourceName}'.toUpperCase();
}
```

- [ ] **Step 4: Run SessionScreen tests**

Run: `flutter test test/screens/session_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/session/session_screen.dart test/screens/session_screen_test.dart
git commit -m "feat(session): add SessionScreen with editable title and transcribing state"
```

---

## Task 19: LibrarySheet + LibraryRow

**Files:**
- Create: `lib/screens/library/library_row.dart`
- Create: `lib/screens/library/library_sheet.dart`

- [ ] **Step 1: Implement LibraryRow**

Create `lib/screens/library/library_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/recording.dart';
import '../../widgets/soft_card.dart';

class LibraryRow extends StatelessWidget {
  const LibraryRow({
    required this.recording,
    required this.onTap,
    super.key,
  });

  final Recording recording;
  final VoidCallback onTap;

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
                Text(_formatDuration(recording.durationSeconds), style: AppTextStyles.mono),
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
```

- [ ] **Step 2: Implement LibrarySheet**

Create `lib/screens/library/library_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/recording.dart';
import '../../widgets/tonal_icon_button.dart';
import 'library_row.dart';

class LibrarySheet extends StatelessWidget {
  const LibrarySheet({
    required this.recordings,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  final List<Recording> recordings;
  final void Function(Recording) onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(recordings);

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
                  TonalIconButton(icon: Icons.close, onPressed: onClose, tooltip: 'Close'),
                ],
              ),
            ),
            Expanded(
              child: recordings.isEmpty
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
                            LibraryRow(recording: r, onTap: () => onTap(r)),
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/library/
git commit -m "feat(library): add LibrarySheet with date-grouped rows and empty state"
```

---

## Task 20: SettingsSheet + AdvancedSettingsView

**Files:**
- Create: `lib/screens/settings/settings_sheet.dart`
- Create: `lib/screens/settings/advanced_settings_view.dart`

- [ ] **Step 1: Implement SettingsSheet**

Create `lib/screens/settings/settings_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../models/audio_source.dart';
import '../../services/settings_service.dart';
import '../../widgets/tonal_icon_button.dart';
import 'advanced_settings_view.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    required this.settings,
    required this.preferredSource,
    required this.allSources,
    required this.onSettingsChanged,
    required this.onPickPreferredSource,
    required this.onClose,
    super.key,
  });

  final AppSettings settings;
  final AudioSource? preferredSource;
  final List<AudioSource> allSources;
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
```

- [ ] **Step 2: Implement AdvancedSettingsView**

Create `lib/screens/settings/advanced_settings_view.dart`:

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings/
git commit -m "feat(settings): add SettingsSheet and AdvancedSettingsView"
```

---

## Task 21: AppController — glue services to UI

**Files:**
- Create: `lib/app/app_controller.dart`

This is plain Dart (no widgets) — it owns the long-lived state and exposes the actions the screens call.

- [ ] **Step 1: Implement AppController**

Create `lib/app/app_controller.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/audio_source.dart';
import '../models/recorder_state.dart';
import '../models/recording.dart';
import '../models/setup_problem.dart';
import '../services/audio_devices_service.dart';
import '../services/binary_detector_service.dart';
import '../services/library_service.dart';
import '../services/paths_service.dart';
import '../services/recorder_service.dart';
import '../services/settings_service.dart';
import '../services/transcriber_service.dart';

/// One-stop owner of background services and reactive state.
/// Widgets subscribe via `addListener`.
class AppController extends ChangeNotifier {
  AppController({
    required this.paths,
    required this.library,
    required this.settingsSvc,
  });

  final PathsService paths;
  final LibraryService library;
  final SettingsService settingsSvc;

  AppSettings settings = AppSettings.defaults;
  String? ffmpegPath;
  String? whisperPath;
  List<AudioSource> sources = const <AudioSource>[];
  AudioSource? selectedSource;
  RecorderState recorderState = RecorderState.idle;
  Duration elapsed = Duration.zero;
  SetupProblem? problem;
  int recordingsCount = 0;

  RecorderService? _recorder;
  Recording? _activeRecording;
  StreamSubscription<RecorderState>? _stateSub;
  Timer? _clock;

  Future<void> bootstrap() async {
    settings = await settingsSvc.load();
    await _detectBinaries();
    await _refreshDevices();
    await _refreshLibraryCount();
    if (sources.isNotEmpty) {
      // Prefer the user's saved choice, then the first system output, then mic.
      AudioSource? preferred;
      if (settings.preferredSourceName != null) {
        preferred = sources.firstWhere(
          (s) => s.name == settings.preferredSourceName,
          orElse: () => sources.first,
        );
      } else {
        preferred = sources.firstWhere(
          (s) => s.kind == AudioSourceKind.systemOutput,
          orElse: () => sources.first,
        );
      }
      selectedSource = preferred;
    }
    notifyListeners();
  }

  Future<void> _detectBinaries() async {
    final ffmpegDetector = BinaryDetectorService(
      candidates: <String>[
        if (settings.ffmpegPathOverride != null) settings.ffmpegPathOverride!,
        ...BinaryDetectorService.defaultCandidatesFor('ffmpeg'),
      ],
    );
    final whisperDetector = BinaryDetectorService(
      candidates: <String>[
        if (settings.whisperPathOverride != null) settings.whisperPathOverride!,
        ...BinaryDetectorService.defaultCandidatesFor('whisper-cli'),
      ],
    );
    ffmpegPath = await ffmpegDetector.locate('ffmpeg');
    whisperPath = await whisperDetector.locate('whisper-cli');

    if (ffmpegPath == null) {
      problem = SetupProblem.ffmpegNotFound;
    } else if (whisperPath == null) {
      problem = SetupProblem.whisperNotFound;
    } else if (settings.modelPathOverride != null &&
        !File(settings.modelPathOverride!).existsSync()) {
      problem = SetupProblem.modelNotFound;
    } else {
      problem = null;
    }
  }

  Future<void> _refreshDevices() async {
    if (ffmpegPath == null) return;
    try {
      final svc = AudioDevicesService(ffmpegPath: ffmpegPath!);
      sources = await svc.list();
      if (sources.where((s) => s.kind == AudioSourceKind.systemOutput).isEmpty &&
          problem == null) {
        problem = SetupProblem.noSystemAudioDevice;
      }
    } on Object {
      sources = const <AudioSource>[];
    }
  }

  Future<void> _refreshLibraryCount() async {
    final all = await library.list();
    recordingsCount = all.length;
  }

  Future<void> changeSettings(AppSettings updated) async {
    settings = updated;
    await settingsSvc.save(updated);
    await _detectBinaries();
    notifyListeners();
  }

  Future<void> selectSource(AudioSource s) async {
    selectedSource = s;
    settings = settings.copyWith(preferredSourceName: s.name);
    await settingsSvc.save(settings);
    notifyListeners();
  }

  Future<Recording?> startRecording() async {
    if (problem != null || ffmpegPath == null || selectedSource == null) return null;
    final id = 'rec_${DateTime.now().millisecondsSinceEpoch}';
    final wavPath = await paths.wavPathFor(id);
    _recorder = RecorderService(ffmpegPath: ffmpegPath!);
    await _recorder!.start(source: selectedSource!, outputWavPath: wavPath);
    _activeRecording = Recording(
      id: id,
      title: '',
      createdAt: DateTime.now().toUtc(),
      durationSeconds: 0,
      wavPath: wavPath,
      sourceName: selectedSource!.name,
      transcript: '',
    );
    _stateSub = _recorder!.state.listen((s) {
      recorderState = s;
      notifyListeners();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed = _recorder?.elapsed() ?? Duration.zero;
      notifyListeners();
    });
    recorderState = RecorderState.recording;
    elapsed = Duration.zero;
    notifyListeners();
    return _activeRecording;
  }

  Future<Recording?> stopRecording() async {
    final rec = _recorder;
    final pending = _activeRecording;
    if (rec == null || pending == null) return null;
    final dur = rec.elapsed();
    await rec.stop();
    _clock?.cancel();
    await _stateSub?.cancel();
    _stateSub = null;
    _recorder = null;
    elapsed = Duration.zero;
    recorderState = RecorderState.idle;

    final completed = pending.copyWith(durationSeconds: dur.inSeconds);
    await library.save(completed);
    await _refreshLibraryCount();
    notifyListeners();
    _activeRecording = null;
    return completed;
  }

  Future<Recording> transcribe(Recording rec) async {
    if (whisperPath == null) return rec;
    final modelPath = settings.modelPathOverride ??
        '${Platform.environment['HOME'] ?? ''}/Models/ggml-base.en.bin';
    if (!File(modelPath).existsSync()) {
      problem = SetupProblem.modelNotFound;
      notifyListeners();
      return rec;
    }
    final svc = TranscriberService(whisperPath: whisperPath!);
    final result = await svc.transcribe(
      wavPath: rec.wavPath,
      modelPath: modelPath,
      language: settings.language,
    );
    final autoTitle =
        rec.title.isEmpty ? Recording.deriveTitle(result.text) : rec.title;
    final updated = rec.copyWith(transcript: result.text, title: autoTitle);
    await library.save(updated);
    return updated;
  }

  Future<void> updateRecording(Recording rec) async {
    await library.save(rec);
    notifyListeners();
  }

  Future<void> deleteRecording(Recording rec) async {
    await library.delete(rec);
    await _refreshLibraryCount();
    notifyListeners();
  }

  Future<List<Recording>> listRecordings() => library.list();

  @override
  void dispose() {
    _stateSub?.cancel();
    _clock?.cancel();
    _recorder?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Quick analyzer pass**

Run: `flutter analyze lib/app/app_controller.dart`
Expected: no errors. Warnings are fine.

- [ ] **Step 3: Commit**

```bash
git add lib/app/app_controller.dart
git commit -m "feat(app): add AppController gluing services and reactive state"
```

---

## Task 22: Replace `main.dart` with new entry point and navigation

**Files:**
- Modify: `lib/main.dart` (replace entire contents)

- [ ] **Step 1: Replace `lib/main.dart`**

Overwrite `lib/main.dart` with:

```dart
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
    // Push session view, kick off transcription in parallel.
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
    // Plan 1: every problem points at Settings; later plans wire deeper paths.
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
    // Plan 1: simple .txt write next to the WAV file.
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
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: 0 errors. Warnings only.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(app): replace main.dart with new shell wiring all services and screens"
```

---

## Task 23: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README contents**

Replace the contents of `README.md` with:

```markdown
# Transcripter

Polished macOS desktop app for recording and transcribing system audio
locally, with no cloud dependency.

## What it does

1. Pick an audio source (system output via BlackHole, or a microphone).
2. Tap the record button. The app captures 16 kHz mono WAV.
3. Tap stop. The app pushes you into a session view and transcribes the
   recording locally using Whisper.

Recordings auto-save and appear in the library. Settings let you switch
language, change the default source, and override binary paths.

## Setup (one-time)

This is Plan 1 of the redesign — the app still expects you to install
the underlying tools yourself. Future plans (2, 3, 4) automate this.

```sh
brew install ffmpeg
brew install whisper-cpp
brew install --cask blackhole-2ch
```

Download a Whisper model:

```sh
mkdir -p ~/Models
curl -L -o ~/Models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

Create a Multi-Output Device in Audio MIDI Setup that includes your
speakers and BlackHole 2ch, then set it as your system output.

Grant microphone permission to your terminal *and* to Transcripter the
first time it requests it.

## Run

```sh
flutter run -d macos
```

## Architecture

- `lib/app/` — theme tokens, navigation glue, AppController.
- `lib/models/` — value types (Recording, AudioSource, RecorderState, SetupProblem).
- `lib/services/` — wrappers around ffmpeg, whisper-cli, the filesystem, settings.
- `lib/screens/` — one folder per surface (record, session, library, settings).
- `lib/widgets/` — small reusables (SoftCard, Pill, TonalIconButton, ErrorBanner).

## Tests

```sh
flutter test
```

## Storage locations

- Recordings: `~/Library/Application Support/transcripter/recordings/`
- Settings: `~/Library/Application Support/transcripter/settings.json`
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for the redesigned app"
```

---

## Task 24: Manual smoke test on macOS

**Files:**
- None. Manual verification.

- [ ] **Step 1: Build and launch**

Run: `flutter run -d macos`

Expected: app launches into the new record screen. Background is cream, brand mark reads "Transcripter", source pill shows the saved BlackHole 2ch (or first available device).

- [ ] **Step 2: Verify idle layout**

Visually check:
- Source pill is centered above the record button.
- Record button is a terracotta circle with a soft warm shadow.
- "00:00" appears below in monospace, faintly colored.
- "Tap to record" hint sits below the timer.
- Footer shows "X recent recordings · Open library →".

- [ ] **Step 3: Tap source pill**

Expected: popover appears below the pill with sections "System output" and "Microphones". Active device has a checkmark. Selecting a new device updates the pill text and persists across relaunches.

- [ ] **Step 4: Start recording**

Tap the record button.

Expected: button morphs to dark ink, timer starts ticking with full color, animated waveform bars appear below. Source pill is dimmed and unresponsive. Header icons (search/settings) dim and become inert. Footer reads "● Recording · 16 kHz mono · Tap button to stop".

- [ ] **Step 5: Stop recording**

Wait at least 3 seconds, then tap the record button again.

Expected: app navigates to the session view with a horizontal slide-in. Title shows "Untitled recording" in italic. Transcribing chip + 3 shimmer bars appear in place of the transcript. After a few seconds (depending on model speed), the transcript appears and the title auto-populates from the first sentence.

- [ ] **Step 6: Edit title, copy, export**

In session view:
- Click the title and type a new name; press Enter. Verify it persists by going back and reopening the recording from the library.
- Tap "Copy text". Verify a snackbar confirms the copy and the clipboard contains the transcript.
- Tap "Export…". Verify a `.txt` file appears next to the `.wav` in `~/Library/Application Support/transcripter/recordings/`.

- [ ] **Step 7: Library**

Return to the record screen and open the library (footer link or ⌕).

Expected: sheet slides up showing the recording grouped under "TODAY". Tapping it opens the session view with the transcript already populated (no re-transcription).

- [ ] **Step 8: Settings**

Open settings (⚙).

Expected: three groups (Recording, Transcription, Advanced). Editing the language saves correctly. Advanced → Tool paths opens the sub-view; saving a blank value clears the override.

- [ ] **Step 9: Error banner**

Quit the app, temporarily rename `/opt/homebrew/bin/ffmpeg` (or whichever path the app found), relaunch.

Expected: warm banner appears at the top of the record screen with "FFmpeg not found", action "Open Settings →". Record button is dimmed and unresponsive. Restore the binary, relaunch — banner disappears.

- [ ] **Step 10: Commit smoke-test checklist as a doc**

Create `docs/superpowers/plans/2026-05-21-plan-1-smoke-test.md`:

```markdown
# Plan 1 Smoke Test — Checklist

Run after each significant change to the record/session/library/settings
flow on macOS.

- [ ] App launches into the record screen with the new theme.
- [ ] Source pill opens the popover; selection persists across relaunch.
- [ ] Record → active state morphs button color, timer, waveform.
- [ ] Stop pushes session view with transcribing placeholder.
- [ ] Title auto-fills from transcript and is editable.
- [ ] Copy text snackbar appears; clipboard contains text.
- [ ] Export writes a .txt file next to the .wav.
- [ ] Library lists today's recording and re-opens it without re-transcribing.
- [ ] Settings → Advanced edits persist; clearing them re-enables auto-detect.
- [ ] Renaming the ffmpeg binary surfaces the warm error banner.
```

Run:
```bash
git add docs/superpowers/plans/2026-05-21-plan-1-smoke-test.md
git commit -m "docs: add Plan 1 smoke test checklist"
```

---

## Wrap-up checks before declaring Plan 1 done

- [ ] `flutter analyze` reports 0 errors.
- [ ] `flutter test` is fully green.
- [ ] Smoke test (Task 24) passes end-to-end on macOS.
- [ ] No reference to the old monolithic UI remains in `lib/`.
- [ ] README accurately describes the current behavior.

Plan 1 is done when all five boxes above are checked.

# Transcripter — Polished macOS Redesign

**Status:** Design approved 2026-05-21
**Scope:** UI redesign + auto-install onboarding for the existing single-screen recorder.
**Out of scope:** Live-while-recording transcription, multi-user accounts, cloud sync, iOS companion.

---

## 1. Summary

Transcripter today is a developer-facing single-screen utility: file-path text fields for `ffmpeg` / `whisper-cli`, raw command output dumps, and a manual setup process that requires installing BlackHole via Homebrew, configuring a Multi-Output Device by hand, and pasting binary paths into the UI.

This redesign turns it into a polished consumer-grade macOS app: a warm-minimalist visual system, a single hero record screen, a document-style session view per recording, and a fully automated first-run setup that downloads the speech model, installs the BlackHole driver, creates the required audio device, and requests microphone permission with as little friction as macOS permits.

Two macOS prompts are unavoidable and are pre-framed by the app:
1. Admin password (BlackHole `.pkg` install).
2. Microphone permission (`AVCaptureDevice.requestAccess`).

Everything else — FFmpeg, Whisper, model download, Core Audio device creation, system-output switching, path detection — is automatic.

---

## 2. Visual System

### Palette

Warm neutrals with terracotta accent. No pure black, no harsh grays. The accent is reserved — used only for the record action, selection state, and the source-active indicator.

| Token | Hex | Use |
|---|---|---|
| `cream` | `#fbf5ec` | Window background |
| `cream-2` | `#f4ecde` | Subtle banded surfaces, button-row backgrounds |
| `paper` | `#ffffff` | Card surfaces |
| `line` | `#ecdfcf` | Borders, dividers |
| `line-soft` | `#f4ecde` | Row separators inside cards |
| `ink` | `#2a1f17` | Primary text, primary buttons |
| `ink-soft` | `#6b5b4a` | Secondary text |
| `ink-faint` | `#a5957f` | Tertiary text, disabled |
| `accent` | `#d96a3a` | Record action, selection, links |
| `accent-deep` | `#b85428` | Record button shadow, hover |
| `accent-soft` | `#f7e5d8` | Selection halo, source pill background |
| `record` | `#c0432a` | Active recording dot |
| `success` | `#4a7c4d` | Checkmarks, confirmation |
| `danger` | `#b3261e` | Destructive actions, errors |

### Typography

- **Display & transcript** — `New York` (system serif fallback: `Georgia`). The transcript is the product; it deserves a typeface.
- **UI chrome** — system sans (`-apple-system`, SF Pro).
- **Timers & file sizes** — `ui-monospace` with `font-variant-numeric: tabular-nums`.

| Role | Family | Size / line-height | Weight |
|---|---|---|---|
| Display | Serif | 32 / 1.10 | 400 |
| Section title | Sans | 17 / 1.2 | 600 |
| Body serif (transcript) | Serif | 15 / 1.55 | 400 |
| Body sans | Sans | 13 / 1.4 | 400 |
| Meta (uppercase) | Sans | 11 / 1.3 | 500, `letter-spacing: 0.12em` |
| Timer | Monospace | 30 / 1.0 | 300 |

### Surfaces

- Cards: white, `border-radius: 10–12px`, shadow `0 1px 2px rgba(60,40,20,.06)`. Hover lifts to `0 4px 12px rgba(60,40,20,.08)`.
- Pills: pure white background, soft shadow, `border-radius: 999px`.
- Buttons: primary uses `ink` (dark brown) on `cream` text, not accent — keeps accent special. Secondary is white with `line` border. Tertiary is `accent` text only.

### Motion

| Action | Duration | Easing |
|---|---|---|
| Page push (record → session) | 320ms | ease-in-out |
| Sheet / popover (library, settings, source) | 240ms | ease-out |
| Record-button pulse (active) | 1.4s | sine, infinite alternate |
| Waveform reaction | realtime, 60fps | — |
| Hover lift | 120ms | ease-out |

---

## 3. Information Architecture

Three primary surfaces, three secondary surfaces, one one-time onboarding flow.

```
First launch ──► Onboarding (6 steps) ──► Record (idle)
                                              ▲
                                              │
                                         Done │
                                              │
Record (idle) ──tap rec──► Record (active) ──tap stop──► Session view
       │
       ├──tap ⌕──► Library (sheet)  ──tap row──► Session view
       │
       ├──tap ⚙──► Settings (sheet)
       │
       └──tap source pill──► Source picker (popover)
```

- **Record** (home) is single-window, no tabs, no sidebars.
- **Session view** is pushed in (slide from right) after Stop. "Done" or "‹ Record" pops back.
- **Library, Settings** open as sheets over the record screen.
- **Source picker** is a popover anchored to the source pill.

---

## 4. Screens

### 4.1 Record (idle / home)

```
┌────────────────────────────────────────┐
│  ● Transcripter              ⌕   ⚙     │
│                                        │
│       ┌──────────────────────────┐     │
│       │ ● System audio · BH 2ch ▾│     │   source pill
│       └──────────────────────────┘     │
│                                        │
│              ┌────────┐                │
│              │   ●●   │                │   record button
│              │ ●●●●●● │                │
│              │   ●●   │                │
│              └────────┘                │
│                                        │
│               00:00                    │   timer (faint)
│             Tap to record              │
│                                        │
├────────────────────────────────────────┤
│ 3 recent recordings    Open library →  │
└────────────────────────────────────────┘
```

**Components:**
- Title bar: brand mark left, two icon buttons right (⌕ library, ⚙ settings).
- Source pill: click → popover (§4.6). Shows active device with a colored dot.
- Record button: 96×96, radial-gradient terracotta, soft shadow.
- Timer: monospace, `ink-faint` color when idle.
- Footer: count of recordings + library link.

**Behavior:**
- Tap record button → starts capture, screen morphs to "active" state (§4.2).
- Tap source pill → opens source picker popover.
- Tap ⌕ or footer link → opens library sheet.
- Tap ⚙ → opens settings sheet.

### 4.2 Record (active)

Same screen as idle, morphed in place:
- Source pill: dimmed, no chevron (locked during recording).
- Record button: morphs to dark `ink` color (now means "stop"), pulse animation begins.
- Timer: switches to full `ink` color, starts counting.
- Below timer: live reactive waveform strip (~25 bars, animated to input level).
- Footer: replaces device count with `● Recording · 16 kHz mono`.
- Top-right icons: disabled while recording (settings and library are not navigable mid-capture).

**Behavior:**
- Tap button → kills `ffmpeg` cleanly (SIGINT, then SIGTERM, then SIGKILL), starts Whisper in the background, pushes session view in with a 320ms slide-in transition.
- Recording is written to `~/Library/Application Support/Transcripter/recordings/YYYY-MM-DD-HHMMSS.wav`.

### 4.3 Session view

Pushed in after Stop. Each recording is treated as a saved document.

```
┌────────────────────────────────────────┐
│  ‹ Record                  ⤓   ⌘C  ⋯   │
├────────────────────────────────────────┤
│  TODAY · 2:14 PM · 0:42 · SYSTEM AUDIO │
│                                        │
│  Product sync                          │   editable serif title
│                                        │
│  ▶  ▌▌▌▌▌·····│······················  │   playback + waveform
│  0:12 / 0:42                           │
│                                        │
│  So the key insight here is that      │
│  BlackHole essentially gives us a     │   transcript (serif)
│  virtual cable from the system…       │
│                                        │
├────────────────────────────────────────┤
│       Delete   Export…  Copy   Done    │
└────────────────────────────────────────┘
```

**Components:**
- Top bar: "‹ Record" back link (`accent` color); ⤓ export, ⌘C copy, ⋯ overflow on the right.
- Body card (white, on cream background):
  - Meta line: uppercase, `ink-soft`. Date, time, duration, audio source.
  - Title: serif, 22–24px. Auto-generated; click to edit (dashed underline on hover).
  - Playback row: 32px circular play button (`ink`), scrubbable waveform, current/total time on the right.
  - Transcript body: serif paragraphs. Hovering a paragraph highlights it with `cream-2` background for selection.
- Bottom toolbar: cream-2 strip with action buttons. Delete is tertiary (`ink-soft` text only), Export/Copy are secondary, Done is primary.

**Behavior:**
- Auto-saved on entry — no save dialog ever.
- Title auto-populates from the first sentence of the transcript (max 60 chars). Falls back to `Recording — Today 2:14 PM` if no transcript yet.
- Click title → edit inline. Enter or blur to commit.
- Export menu: `.txt`, `.md`, `.srt` (if timestamps available), `.wav` (audio).
- Copy: copies plain text of transcript to clipboard.
- Done / ‹ Record → pop back to record-ready home.

### 4.4 Session view — transcribing state

Same layout as §4.3 but:
- Title shows `Untitled recording` in italic `ink-faint`.
- Playback row is at 50% opacity (audio is ready, but de-emphasized).
- Transcript area replaced with:
  - A spinner + label: `Transcribing locally with Whisper base.en…`
  - Three shimmer placeholder lines below it (animated gradient).
- Export and Copy icons in the top bar are dimmed (40% opacity).
- The recording is already saved; users can hit ‹ Record to leave and the transcription continues in the background. They'll find it ready in the library.

### 4.5 Library (sheet)

Slides up from the record screen. Triggered by ⌕ or the footer link.

```
┌────────────────────────────────────────┐
│  Library                        ✕      │
├────────────────────────────────────────┤
│  ⌕ Search transcripts…                 │
│                                        │
│  TODAY                                 │
│  ┌──────────────────────────────────┐  │
│  │ Product sync               0:42  │  │
│  │ 2:14 PM · System audio           │  │
│  │ So the key insight here is…      │  │
│  └──────────────────────────────────┘  │
│                                        │
│  YESTERDAY                             │
│  ┌──────────────────────────────────┐  │
│  │ Call with Maria            8:24  │  │
│  │ ...                              │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

**Components:**
- Header: serif title, close button.
- Search bar: cream-paper background, ⌕ icon left, placeholder text.
- Section headings: uppercase meta style, grouped by relative date (`Today`, `Yesterday`, `Last week`, `This month`, `Older`).
- Row card: title (serif), duration (monospace, right), meta line, single-line snippet of transcript (serif, ellipsized).

**Behavior:**
- Tap row → opens session view (§4.3). Library sheet stays in the stack; ‹ Record returns to record screen, dismissing the library too.
- Search filters by title and transcript content; results not grouped by date when searching (flat list, most-recent first).
- Empty state: centered `◔` glyph in `ink-faint`, "No recordings yet" headline, brief sub-line pointing back at the record button.

### 4.6 Settings (sheet)

Three grouped sections; designed so 95% of users never open it.

**Recording**
- Default audio source — picker, defaults to "System audio (BlackHole 2ch)".
- Save recordings to — folder picker, defaults to `~/Library/Application Support/Transcripter/recordings`.

**Transcription**
- Language — picker (English, Spanish, French, German, … `auto-detect`).
- Model — currently active model with size + status. "Change…" opens a model-management view (download/delete other Whisper variants).
- Transcribe automatically — toggle (default ON). When OFF, the session view shows a "Transcribe now" button instead of running automatically.

**Advanced**
- Tool paths — "Edit" pushes a sub-view with the existing `ffmpeg` and `whisper-cli` path fields. Defaults to the bundled binaries; visible for power users who want to override.
- Remove BlackHole and Multi-Output — destructive button. Confirms before reversing the install.

### 4.7 Source picker (popover)

Popover anchored beneath the source pill.

- Width ~340px, white background, large shadow.
- Sectioned by purpose:
  - **System output** — virtual devices that can capture speaker output (BlackHole 2ch, etc.).
  - **Microphones** — physical mic inputs.
- Each row: 28px square icon, name (sans-medium), one-line description (sans-small), checkmark on active.
- Footer: cream banded strip with link "Set up system audio capture →" — re-opens the onboarding driver step if BlackHole is missing or broken.

### 4.8 Error / permission denied (record screen banner)

Same record screen, dimmed and inert, with a warm-tinted banner above the disabled button.

- Banner: `#fef0e8` background, `#f4c8b1` border.
- Content: ⚠ icon, title (e.g., "Transcripter needs microphone access"), one-line cause, single action link ("Open System Settings →") in `accent`.
- Record button and timer are pushed to `ink-faint`/dimmed, with `pointer-events: none`.
- Auto-resolves: when permission/condition is fixed, the banner removes itself and the screen returns to normal.

Used for: microphone permission denied, FFmpeg binary failed to spawn, output device disappeared mid-session.

---

## 5. Onboarding (first-run flow)

Six steps, ~45 seconds wall time on a good connection. **No skip path** — auto-install is the only way in. (Settings later lets the user uninstall BlackHole if they change their mind.)

### Step 1 · Welcome

- One screen, one button.
- Brand mark, two-line serif headline ("Record & transcribe / system audio, privately"), one paragraph of body copy, "Get started →" primary button.
- Meta line in `ink-faint` at the bottom: `~150 MB download · admin password needed once`. Sets expectations.

### Step 2 · Setting things up (live checklist)

Five-row checklist with per-row state and an aggregate progress bar.

| Row | What happens |
|---|---|
| FFmpeg ready | Immediately ✓ (bundled in `.app/Contents/Resources/bin/ffmpeg`). |
| Whisper engine ready | Immediately ✓ (bundled in `.app/Contents/Resources/bin/whisper-cli`). |
| Downloading speech model | Streams `ggml-base.en.bin` (~142 MB) from HuggingFace into `~/Library/Application Support/Transcripter/models/`. Shows progress percentage and MB counter. Resumable. |
| Install BlackHole audio driver | Triggers step 3. |
| Create Multi-Output device | Programmatic via Core Audio. Includes default speaker/headphones + BlackHole 2ch. Named "Transcripter Output". |
| Request microphone access | Triggers step 4. |

The model download happens in parallel with step 3 if the user reaches the admin prompt while the download is still running.

### Step 3 · Admin password (pre-framed)

- App screen behind: dimmed copy explaining "Installing BlackHole audio driver" with a "Why is BlackHole needed?" link.
- macOS native auth dialog appears in front (we trigger it via `osascript -e 'do shell script "installer -pkg ... with administrator privileges"'` or equivalent native plugin call).
- On cancel → banner: "Couldn't install BlackHole. Try again." with retry button. Onboarding state persists.

### Step 4 · Microphone permission (pre-framed)

- App screen pre-frames: "One more click. macOS treats BlackHole as a microphone. Click **Allow** on the next prompt."
- App calls `AVCaptureDevice.requestAccess(for: .audio)`, native dialog appears.
- On deny → error-banner state (§4.8) appears immediately on the record screen after onboarding "finishes", offering "Open System Settings →".

### Step 5 · Test it works

- App plays a 2-second sine tone through the new Multi-Output Device.
- Simultaneously records via FFmpeg from BlackHole 2ch.
- Live level meter in the UI confirms incoming audio.
- "Looks good →" advances. "Test again" replays the tone. If silent for 3 seconds, surface a help link.

### Step 6 · Ready

- Big success checkmark, "You're set" headline, recap of installed components as ticked rows.
- "Start recording →" lands the user on the record screen (§4.1).
- This screen is shown once. Subsequent launches skip the entire onboarding flow.

### Resumability and idempotence

- **Resumable**: each step's success is persisted to `~/Library/Application Support/Transcripter/setup-state.json`. Quitting mid-flow resumes at the next incomplete step on next launch.
- **Idempotent silent verification**: on every launch (after onboarding completes), the app checks each component (binary present + executable, model file present + correct hash, BlackHole driver loaded, Multi-Output Device exists). If any check fails, the relevant banner appears on the record screen with a one-tap re-install action — full onboarding is not re-run.
- **Uninstall**: Settings → "Remove BlackHole and Multi-Output" runs the inverse: removes the Multi-Output Device via Core Audio, runs BlackHole's uninstall script (or shows manual instructions if the uninstaller isn't present). The app remains functional in mic-only mode after this.

---

## 6. Technical Scope

### What changes structurally

The current `lib/main.dart` is a single 768-line file. The redesign requires splitting concerns and adding a native macOS plugin. Proposed structure:

```
lib/
  main.dart                 # App entry, MaterialApp, theme
  app/
    theme.dart              # Color tokens, text styles
    routes.dart             # Navigation (record → session, sheets)
  screens/
    onboarding/
      onboarding_flow.dart  # 6-step orchestrator
      welcome_screen.dart
      setup_screen.dart
      auth_prompts.dart     # Pre-frame screens for macOS dialogs
      test_screen.dart
      ready_screen.dart
    record/
      record_screen.dart    # Idle + active states
      source_pill.dart
      source_picker.dart    # Popover
    session/
      session_screen.dart
      session_toolbar.dart
      transcript_view.dart
    library/
      library_sheet.dart
    settings/
      settings_sheet.dart
      advanced_settings.dart
  models/
    recording.dart          # Recording + transcript value type
    audio_source.dart
    setup_state.dart
  services/
    recorder_service.dart   # Wraps FFmpeg process
    transcriber_service.dart # Wraps whisper-cli process
    library_service.dart    # Persisted list of recordings
    setup_service.dart      # Orchestrates onboarding, calls native plugin
    audio_devices_service.dart # Native plugin wrapper

macos/Runner/
  Plugins/
    TranscripterNative/
      AudioDeviceController.swift   # Core Audio: list, create Multi-Output, set system output
      BlackHoleInstaller.swift      # Privileged installer via NSWorkspace + AuthorizationServices
      PermissionController.swift    # AVCaptureDevice mic permission
      ModelDownloader.swift         # NSURLSession download, resumable
      TranscripterPlugin.swift      # Method channel dispatch
```

### Native plugin responsibilities (Swift / Method Channel)

1. **`enumerateAudioDevices()`** — list AVFoundation/Core Audio input devices with name, UID, channel count, sample rate. Distinguishes virtual vs physical inputs.
2. **`createMultiOutputDevice(name:, deviceUIDs:)`** — Core Audio `AudioHardwareCreateAggregateDevice` with `kAudioAggregateDeviceIsStackedKey` for multi-output behavior.
3. **`setDefaultSystemOutput(uid:)`** — sets `kAudioHardwarePropertyDefaultOutputDevice`.
4. **`installPackage(path:)`** — uses `AuthorizationCreate` + `AuthorizationExecuteWithPrivileges` (or the modern replacement `SMJobBless` / shell out to `installer` via `osascript`) to install the bundled BlackHole `.pkg`.
5. **`isBlackHoleInstalled()`** — checks for `/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver`.
6. **`uninstallBlackHole()`** — runs the inverse, also requires admin.
7. **`requestMicrophonePermission()`** — wraps `AVCaptureDevice.requestAccess(for: .audio)`. Returns granted/denied.
8. **`micPermissionStatus()`** — synchronous read of `AVCaptureDevice.authorizationStatus(for: .audio)`.
9. **`downloadModel(url:, dest:, progressChannel:)`** — `URLSession` download task with resumability, emits progress via an event channel.
10. **`playTestTone(deviceUID:, durationMs:)`** — for the test step. Generates a sine via `AVAudioEngine` and routes it to the specified device.

### Bundled binaries

- **FFmpeg** — LGPL build (no `--enable-gpl`, no `--enable-libx264`/etc.). We don't need video codecs; only PCM WAV output. Approx 25 MB universal binary.
- **whisper-cli** — `whisper.cpp` built with Metal backend for Apple Silicon. Approx 3 MB.
- Both code-signed and notarized as part of the app build pipeline. Path resolved at runtime from `Bundle.main.url(forResource:withExtension:subdirectory:)`.

### Bundled BlackHole

- The 2ch `.pkg` from the official BlackHole release, shipped inside `.app/Contents/Resources/`.
- Verified by SHA-256 at build time; install is gated on that check.
- License: GPL-3. Bundling and installing the unmodified `.pkg` is permitted; we expose the source URL and license in Settings → About.

### Model storage

- Default model: `ggml-base.en.bin` (~142 MB).
- Downloaded to `~/Library/Application Support/Transcripter/models/`.
- Settings → Model lets the user download tiny / small / medium variants and pick the active one.

### Recording storage

- Default folder: `~/Library/Application Support/Transcripter/recordings/`.
- File format: 16 kHz mono PCM WAV (matches Whisper's preferred input — no conversion step).
- Filename: `YYYY-MM-DD-HHMMSS.wav`.
- Metadata sidecar: `YYYY-MM-DD-HHMMSS.json` with title, transcript, duration, source device.

### State persistence

- `setup-state.json` — onboarding completion flags, last-resumed step.
- `library/index.json` — cached list of recordings with metadata for fast library load.
- `settings.json` — user preferences (language, default source, model, auto-transcribe).

### License notes (need to verify before distribution)

- **FFmpeg** (LGPL build) — bundling permitted; we must ship the source URL and link to it in Settings → About.
- **BlackHole** (GPL-3) — bundling and redistributing the `.pkg` permitted; we must ship the source URL and a copy of the GPL-3 license text.
- **whisper.cpp** (MIT) — permissive; attribution in About.
- **Whisper models** (MIT for ggml conversions of the base set) — attribute OpenAI for the model weights.

---

## 7. Out of Scope (for this redesign)

- Live transcription during recording (only post-recording for now).
- Cloud sync, accounts, sharing.
- iOS / iPad companion.
- Multi-track recording (system audio + mic simultaneously).
- Speaker diarization.
- Custom audio HAL extension to replace BlackHole.
- Plugin integrations (Zoom, Teams, etc.).

---

## 8. Open Questions

None blocking. The following are deferred to implementation:

- Exact Swift API for creating a Multi-Output (as opposed to Aggregate) Device — verify with Core Audio docs during native plugin work.
- Whether to use `osascript` + `installer` or `SMJobBless` for the privileged BlackHole install — `osascript` is simpler and well-understood, `SMJobBless` is more modern but adds entitlement complexity.
- Final model variant default — base.en is a good balance, but small.en is half the size with marginal quality drop. Could decide based on user's Mac (Apple Silicon → base, Intel → small).

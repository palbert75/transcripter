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

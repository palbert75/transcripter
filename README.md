# Transcripter

Transcripter is a Flutter macOS desktop app for recording routed system audio
to a transcription-ready WAV file, then transcribing it locally with
`whisper.cpp`.

## Features

- Record macOS system audio routed through an AVFoundation input device.
- Save audio as 16 kHz mono PCM WAV for speech transcription.
- List available AVFoundation audio devices through `ffmpeg`.
- Run local `whisper.cpp` transcription against a selected model file.
- Keep recording and transcription output visible in the app log.

## How It Works

The app is intentionally simple:

- Flutter provides the macOS GUI.
- `ffmpeg` records an AVFoundation input device into 16 kHz mono PCM WAV.
- `whisper.cpp` transcribes the recorded WAV locally after capture.

This means macOS still needs a virtual audio device for speaker/output capture. The recommended setup is BlackHole 2ch plus a macOS Multi-Output Device that includes both your real speakers/headphones and BlackHole.

## Requirements

- macOS with Flutter desktop support enabled.
- `ffmpeg`.
- `whisper.cpp`.
- BlackHole 2ch or another virtual audio device that exposes system output as
  an input device.
- A compatible `whisper.cpp` GGML model file.

## Local Setup

Install the external tools:

```sh
brew install ffmpeg
brew install whisper-cpp
brew install --cask blackhole-2ch
```

Download a `whisper.cpp` GGML model file. Homebrew does not install models:

```sh
mkdir -p ~/Models
curl -L -o ~/Models/ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

Then run the app:

```sh
flutter run -d macos
```

## Usage

In the app:

1. Click `List Devices`.
2. Copy the BlackHole audio input name or numeric index into `AVFoundation input device`.
3. Click `Record`.
4. Click `Stop`.
5. Confirm `whisper.cpp binary` is `/opt/homebrew/bin/whisper-cli`.
6. Confirm `Model file` points to the downloaded model.
7. Click `Transcribe WAV`.

## Why BlackHole Is Still Needed

Normal macOS apps cannot directly capture arbitrary speaker output through a simple CLI command. A virtual input device converts system output into something AVFoundation can record. For a polished product, the app should guide the user through this routing or include a custom audio driver/extension strategy, which is a larger and more sensitive install path.

## Standalone Product Direction

The clean open-source path is:

- Bundle a signed `ffmpeg` binary for recording.
- Bundle `whisper.cpp` for local Apple Silicon transcription.
- Store/download Whisper models into app support storage.
- Add a native macOS plugin for better permissions, device enumeration, file picking, and packaged binary paths.
- Keep BlackHole as a prerequisite first, then evaluate whether a bundled system extension is worth the support and signing burden.

Check all licenses before distribution. FFmpeg can be LGPL or GPL depending on build flags, BlackHole is open source but has driver distribution implications, and Whisper model files have their own license terms.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

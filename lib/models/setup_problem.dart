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

  /// True only for problems that prevent the recorder from starting at all.
  /// Missing whisper-cli or a model means we can't *transcribe*, but the
  /// user can still capture audio; only banner them, don't dim the button.
  bool get blocksRecording {
    switch (this) {
      case SetupProblem.ffmpegNotFound:
      case SetupProblem.microphonePermissionDenied:
        return true;
      case SetupProblem.whisperNotFound:
      case SetupProblem.modelNotFound:
      case SetupProblem.noSystemAudioDevice:
        return false;
    }
  }
}

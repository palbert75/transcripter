import 'dart:io';

/// Finds CLI binaries (ffmpeg, whisper-cli) without relying on the shell
/// PATH inheritance behavior of GUI apps (which is unreliable on macOS).
/// Looks at well-known absolute paths in order.
class BinaryDetectorService {
  BinaryDetectorService({required this.candidates});

  final List<String> candidates;

  /// Returns the first candidate path that exists, or null.
  Future<String?> locate(String name) async {
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

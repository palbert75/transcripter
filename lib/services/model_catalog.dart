/// One downloadable Whisper.cpp GGML model.
class WhisperModel {
  const WhisperModel({
    required this.id,
    required this.label,
    required this.filename,
    required this.approximateBytes,
    required this.multilingual,
    this.description,
  });

  /// Stable id used in settings and URLs (e.g. "base.en").
  final String id;

  /// Human label shown in the picker (e.g. "Base · English").
  final String label;

  /// The on-disk filename (e.g. "ggml-base.en.bin").
  final String filename;

  /// Approximate download size in bytes. Surfaced in the UI so users
  /// know what they're committing to before a multi-hundred-MB download.
  final int approximateBytes;

  /// False for English-only models (".en" variants), true otherwise.
  final bool multilingual;

  /// Optional one-liner shown under the label (e.g. "Best for Hungarian and
  /// other non-English audio"). Null falls back to a generic size/filename line.
  final String? description;
}

/// Read-only catalog of the Whisper models we offer. Hosted at the
/// official ggerganov/whisper.cpp HuggingFace repository.
class ModelCatalog {
  ModelCatalog._();

  static const String _hfBase =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  static const List<WhisperModel> all = <WhisperModel>[
    WhisperModel(
      id: 'tiny.en',
      label: 'Tiny · English',
      filename: 'ggml-tiny.en.bin',
      approximateBytes: 75 * 1024 * 1024,
      multilingual: false,
      description: 'Fastest, lower accuracy. English-only.',
    ),
    WhisperModel(
      id: 'base.en',
      label: 'Base · English (recommended)',
      filename: 'ggml-base.en.bin',
      approximateBytes: 142 * 1024 * 1024,
      multilingual: false,
      description: 'Good balance of speed and accuracy. English-only.',
    ),
    WhisperModel(
      id: 'small.en',
      label: 'Small · English',
      filename: 'ggml-small.en.bin',
      approximateBytes: 466 * 1024 * 1024,
      multilingual: false,
      description: 'Higher accuracy than Base. English-only.',
    ),
    WhisperModel(
      id: 'base',
      label: 'Base · Multilingual',
      filename: 'ggml-base.bin',
      approximateBytes: 142 * 1024 * 1024,
      multilingual: true,
      description:
          'Supports 99 languages incl. Hungarian. Lighter accuracy on non-English.',
    ),
    WhisperModel(
      id: 'small',
      label: 'Small · Multilingual',
      filename: 'ggml-small.bin',
      approximateBytes: 466 * 1024 * 1024,
      multilingual: true,
      description:
          'Good for Hungarian and other non-English audio with reasonable speed.',
    ),
    WhisperModel(
      id: 'medium',
      label: 'Medium · Multilingual',
      filename: 'ggml-medium.bin',
      approximateBytes: 1530 * 1024 * 1024,
      multilingual: true,
      description:
          'Strong accuracy on Hungarian and other non-English audio. Slower.',
    ),
    WhisperModel(
      id: 'large-v3',
      label: 'Large v3 · Multilingual (best)',
      filename: 'ggml-large-v3.bin',
      approximateBytes: 3094 * 1024 * 1024,
      multilingual: true,
      description:
          'Highest accuracy across all 99 languages. Slow to download and transcribe.',
    ),
  ];

  static Uri urlFor(WhisperModel m) => Uri.parse('$_hfBase/${m.filename}');
}

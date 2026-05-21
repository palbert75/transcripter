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

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

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        durationSeconds: json['durationSeconds'] as int,
        wavPath: json['wavPath'] as String,
        sourceName: json['sourceName'] as String,
        transcript: json['transcript'] as String,
      );

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

  /// Derive a human title from the first sentence of a transcript.
  /// Returns at most 60 chars, plus an ellipsis if it had to truncate.
  static String deriveTitle(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return '';
    // Sentence boundary heuristic. Good enough for English voice prompts.
    final endMatch = RegExp(r'[.!?]\s').firstMatch(trimmed);
    String candidate;
    if (endMatch != null) {
      // Found a sentence boundary - use the complete sentence
      candidate = trimmed.substring(0, endMatch.end - 1);
    } else {
      // No sentence boundary found - use the whole text if reasonably short,
      // otherwise truncate
      candidate = trimmed;
      if (candidate.length > 60) {
        candidate = '${candidate.substring(0, 60).trimRight()}…';
      }
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

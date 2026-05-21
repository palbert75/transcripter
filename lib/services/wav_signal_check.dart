import 'dart:io';
import 'dart:typed_data';

/// Result of inspecting a freshly captured WAV file for actual audio content.
class WavSignalReport {
  const WavSignalReport({
    required this.maxAbs,
    required this.sampleCount,
  });

  /// Peak |sample| in the data (0..32767 for 16-bit PCM). Below ~50 is
  /// effectively silence (digital noise floor).
  final int maxAbs;

  /// Number of 16-bit mono samples read.
  final int sampleCount;

  /// Treat anything below this peak as "silent enough to warn about".
  /// 100/32767 ≈ -50 dBFS.
  static const int silentThreshold = 100;

  bool get isSilent => maxAbs < silentThreshold;
}

/// Reads a 16 kHz mono 16-bit PCM WAV (the only format the recorder writes
/// in this app) and reports its peak amplitude. Returns null if the file
/// is missing or too small to inspect.
Future<WavSignalReport?> inspectWav(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  // Minimal sanity: 44-byte WAV header + at least a few samples.
  if (bytes.length < 64) return null;

  // Find the "data" chunk rather than trusting a fixed offset — ffmpeg can
  // emit a JUNK chunk between fmt and data.
  final dataOffset = _findDataChunk(bytes);
  if (dataOffset < 0 || dataOffset >= bytes.length) return null;

  final pcm = ByteData.sublistView(bytes, dataOffset);
  final count = pcm.lengthInBytes ~/ 2;
  var maxAbs = 0;
  for (var i = 0; i < count; i++) {
    final sample = pcm.getInt16(i * 2, Endian.little);
    final abs = sample < 0 ? -sample : sample;
    if (abs > maxAbs) maxAbs = abs;
  }
  return WavSignalReport(maxAbs: maxAbs, sampleCount: count);
}

int _findDataChunk(Uint8List bytes) {
  // Skip the 12-byte RIFF header. Each chunk is [4-byte tag][4-byte LE size].
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = ByteData.sublistView(bytes, offset + 4, offset + 8)
        .getUint32(0, Endian.little);
    if (tag == 'data') return offset + 8;
    offset += 8 + size;
  }
  return -1;
}

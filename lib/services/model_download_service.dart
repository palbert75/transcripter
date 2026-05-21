import 'dart:async';
import 'dart:io';

/// Progress emitted while a model is downloading.
class DownloadProgress {
  const DownloadProgress({required this.bytesReceived, required this.totalBytes});

  final int bytesReceived;

  /// Null until the server has sent Content-Length (which HuggingFace does).
  final int? totalBytes;

  /// 0.0 .. 1.0, or null if total is unknown.
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return bytesReceived / total;
  }
}

/// User cancelled the download.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => 'Download cancelled';
}

/// Cooperative cancellation handle passed into [ModelDownloadService.download].
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

typedef HttpClientFactory = HttpClient Function();

/// Streams a Whisper model from the network to a local file with progress
/// updates. Writes to a `.partial` sibling first and renames on success so
/// a half-finished download never masquerades as a valid model.
class ModelDownloadService {
  ModelDownloadService({HttpClientFactory? clientFactory})
      : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClientFactory _clientFactory;

  /// Downloads [url] to [destinationPath]. Yields one [DownloadProgress]
  /// per ~64 KB chunk, plus a final event when the file is closed. If the
  /// caller cancels via [cancelToken], the partial file is deleted and a
  /// [DownloadCancelled] exception is thrown.
  Stream<DownloadProgress> download({
    required Uri url,
    required String destinationPath,
    required CancelToken cancelToken,
  }) async* {
    final partialPath = '$destinationPath.partial';
    final partial = File(partialPath);
    if (partial.existsSync()) await partial.delete();
    if (!partial.parent.existsSync()) {
      await partial.parent.create(recursive: true);
    }

    final client = _clientFactory();
    client.userAgent = 'transcripter/1.0';
    HttpClientResponse? response;
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      // HuggingFace mirrors live behind a CDN that loves redirects.
      request.followRedirects = true;
      request.maxRedirects = 5;
      response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'Unexpected status ${response.statusCode} for $url',
          uri: url,
        );
      }
      final total = response.contentLength >= 0 ? response.contentLength : null;
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (cancelToken.isCancelled) {
          throw const DownloadCancelled();
        }
        sink.add(chunk);
        received += chunk.length;
        yield DownloadProgress(bytesReceived: received, totalBytes: total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      await partial.rename(destinationPath);
      yield DownloadProgress(bytesReceived: received, totalBytes: total);
    } finally {
      if (sink != null) {
        await sink.flush();
        await sink.close();
      }
      if (partial.existsSync()) {
        // Either we cancelled or threw — never leave a bogus partial behind.
        try {
          await partial.delete();
        } on FileSystemException {
          // Best-effort; another process may already have removed it.
        }
      }
      client.close(force: true);
    }
  }
}

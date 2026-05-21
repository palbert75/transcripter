import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/model_download_service.dart';

void main() {
  late HttpServer server;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('model_download_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    await server.close(force: true);
  });

  Future<Uri> serve(Uint8List payload, {int statusCode = 200}) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response.statusCode = statusCode;
      if (statusCode == 200) {
        req.response.headers.contentType = ContentType.binary;
        req.response.contentLength = payload.length;
        req.response.add(payload);
      }
      await req.response.close();
    });
    return Uri.parse('http://127.0.0.1:${server.port}/ggml-base.en.bin');
  }

  test('downloads to disk and yields cumulative progress', () async {
    final payload = Uint8List.fromList(List<int>.generate(8 * 1024, (i) => i % 256));
    final url = await serve(payload);
    final svc = ModelDownloadService();
    final dest = '${tempDir.path}/model.bin';

    final updates = <DownloadProgress>[];
    await for (final p in svc.download(
      url: url,
      destinationPath: dest,
      cancelToken: CancelToken(),
    )) {
      updates.add(p);
    }

    expect(File(dest).existsSync(), isTrue);
    expect(File(dest).lengthSync(), payload.length);
    expect(updates, isNotEmpty);
    expect(updates.last.bytesReceived, payload.length);
    expect(updates.last.totalBytes, payload.length);
    expect(updates.last.fraction, 1.0);
  });

  test('cancellation removes the partial file and throws', () async {
    final payload = Uint8List(8 * 1024 * 1024); // 8 MiB
    final url = await serve(payload);
    final svc = ModelDownloadService();
    final dest = '${tempDir.path}/cancelled.bin';
    final token = CancelToken();

    final stream = svc.download(
      url: url,
      destinationPath: dest,
      cancelToken: token,
    );

    expect(
      () async {
        await for (final progress in stream) {
          if (progress.bytesReceived > 0) token.cancel();
        }
      },
      throwsA(isA<DownloadCancelled>()),
    );

    // Final cleanup happens in the stream's finally block; allow it to run.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(File(dest).existsSync(), isFalse);
    expect(File('$dest.partial').existsSync(), isFalse);
  });

  test('throws when the server returns a non-200 status', () async {
    final url = await serve(Uint8List(0), statusCode: 404);
    final svc = ModelDownloadService();
    final dest = '${tempDir.path}/missing.bin';

    expect(
      () => svc
          .download(
            url: url,
            destinationPath: dest,
            cancelToken: CancelToken(),
          )
          .drain<void>(),
      throwsA(isA<HttpException>()),
    );
  });
}

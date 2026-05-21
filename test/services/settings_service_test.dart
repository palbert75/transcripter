import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/paths_service.dart';
import 'package:transcripter/services/settings_service.dart';

void main() {
  late Directory tempRoot;
  late SettingsService svc;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('settings_');
    svc = SettingsService(paths: PathsService(appSupportRoot: tempRoot));
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('load returns defaults when no file exists', () async {
    final s = await svc.load();
    expect(s.language, 'en');
    expect(s.ffmpegPathOverride, isNull);
    expect(s.preferredSourceName, isNull);
  });

  test('save then load round-trips', () async {
    await svc.save(const AppSettings(
      language: 'fr',
      ffmpegPathOverride: '/custom/ffmpeg',
      whisperPathOverride: null,
      modelPathOverride: '/custom/ggml.bin',
      preferredSourceName: 'BlackHole 2ch',
    ));
    final loaded = await svc.load();
    expect(loaded.language, 'fr');
    expect(loaded.ffmpegPathOverride, '/custom/ffmpeg');
    expect(loaded.modelPathOverride, '/custom/ggml.bin');
    expect(loaded.preferredSourceName, 'BlackHole 2ch');
  });

  test('copyWith with clearFfmpegOverride nulls out a previously-set override', () {
    const before = AppSettings(
      language: 'en',
      ffmpegPathOverride: '/x/ffmpeg',
      whisperPathOverride: null,
      modelPathOverride: null,
      preferredSourceName: null,
    );
    final after = before.copyWith(clearFfmpegOverride: true);
    expect(after.ffmpegPathOverride, isNull);
  });
}

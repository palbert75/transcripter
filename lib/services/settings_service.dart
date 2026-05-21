import 'dart:convert';
import 'dart:io';

import 'paths_service.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.ffmpegPathOverride,
    required this.whisperPathOverride,
    required this.modelPathOverride,
    required this.preferredSourceName,
  });

  final String language;
  final String? ffmpegPathOverride;
  final String? whisperPathOverride;
  final String? modelPathOverride;
  final String? preferredSourceName;

  static const AppSettings defaults = AppSettings(
    language: 'en',
    ffmpegPathOverride: null,
    whisperPathOverride: null,
    modelPathOverride: null,
    preferredSourceName: null,
  );

  /// Returns a copy with the named fields replaced. Pass `clearX: true`
  /// for nullable fields to explicitly null them out — `value ?? this.value`
  /// can't tell "don't change" from "set to null".
  AppSettings copyWith({
    String? language,
    String? ffmpegPathOverride,
    bool clearFfmpegOverride = false,
    String? whisperPathOverride,
    bool clearWhisperOverride = false,
    String? modelPathOverride,
    bool clearModelOverride = false,
    String? preferredSourceName,
    bool clearPreferredSource = false,
  }) {
    return AppSettings(
      language: language ?? this.language,
      ffmpegPathOverride: clearFfmpegOverride
          ? null
          : (ffmpegPathOverride ?? this.ffmpegPathOverride),
      whisperPathOverride: clearWhisperOverride
          ? null
          : (whisperPathOverride ?? this.whisperPathOverride),
      modelPathOverride: clearModelOverride
          ? null
          : (modelPathOverride ?? this.modelPathOverride),
      preferredSourceName: clearPreferredSource
          ? null
          : (preferredSourceName ?? this.preferredSourceName),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'language': language,
        'ffmpegPathOverride': ffmpegPathOverride,
        'whisperPathOverride': whisperPathOverride,
        'modelPathOverride': modelPathOverride,
        'preferredSourceName': preferredSourceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        language: (json['language'] as String?) ?? defaults.language,
        ffmpegPathOverride: json['ffmpegPathOverride'] as String?,
        whisperPathOverride: json['whisperPathOverride'] as String?,
        modelPathOverride: json['modelPathOverride'] as String?,
        preferredSourceName: json['preferredSourceName'] as String?,
      );
}

class SettingsService {
  SettingsService({required this.paths});

  final PathsService paths;

  Future<AppSettings> load() async {
    final file = await paths.settingsFile();
    if (!file.existsSync()) return AppSettings.defaults;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } on FormatException {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await paths.settingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}

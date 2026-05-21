import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../services/model_catalog.dart';
import '../../services/model_download_service.dart';

/// Lists available Whisper models, marks downloaded ones, and offers
/// in-app downloads with progress. Tapping a downloaded row sets it as
/// the active model via [onModelSelected].
class ModelsView extends StatefulWidget {
  const ModelsView({
    required this.modelsDir,
    required this.activePath,
    required this.onModelSelected,
    super.key,
  });

  /// Directory where downloaded model `.bin` files are stored.
  final Directory modelsDir;

  /// Absolute path of the currently active model, or null.
  final String? activePath;

  /// Called when the user picks a downloaded model. Receives its absolute
  /// path; pass null to clear the override and go back to auto-detect.
  final void Function(String? absolutePath) onModelSelected;

  @override
  State<ModelsView> createState() => _ModelsViewState();
}

class _ModelsViewState extends State<ModelsView> {
  final ModelDownloadService _downloader = ModelDownloadService();
  WhisperModel? _activeDownload;
  CancelToken? _cancelToken;
  StreamSubscription<DownloadProgress>? _progressSub;
  DownloadProgress? _progress;
  String? _error;

  @override
  void dispose() {
    _cancelToken?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  String _pathFor(WhisperModel m) => '${widget.modelsDir.path}/${m.filename}';

  bool _isDownloaded(WhisperModel m) => File(_pathFor(m)).existsSync();

  bool _isActive(WhisperModel m) =>
      widget.activePath != null && widget.activePath == _pathFor(m);

  Future<void> _startDownload(WhisperModel m) async {
    setState(() {
      _activeDownload = m;
      _cancelToken = CancelToken();
      _progress = const DownloadProgress(bytesReceived: 0, totalBytes: null);
      _error = null;
    });
    try {
      if (!widget.modelsDir.existsSync()) {
        await widget.modelsDir.create(recursive: true);
      }
      await for (final progress in _downloader.download(
        url: ModelCatalog.urlFor(m),
        destinationPath: _pathFor(m),
        cancelToken: _cancelToken!,
      )) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
      if (!mounted) return;
      // Auto-select the freshly-downloaded model.
      widget.onModelSelected(_pathFor(m));
      setState(() {
        _activeDownload = null;
        _cancelToken = null;
        _progress = null;
      });
    } on DownloadCancelled {
      if (!mounted) return;
      setState(() {
        _activeDownload = null;
        _cancelToken = null;
        _progress = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _activeDownload = null;
        _cancelToken = null;
        _progress = null;
        _error = error.toString();
      });
    }
  }

  void _cancel() {
    _cancelToken?.cancel();
  }

  Future<void> _deleteModel(WhisperModel m) async {
    final file = File(_pathFor(m));
    if (!file.existsSync()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${m.label}?'),
        content: Text(
          '${m.filename} will be removed from ${widget.modelsDir.path}.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await file.delete();
    if (_isActive(m)) widget.onModelSelected(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.cream,
      appBar: AppBar(
        backgroundColor: ColorTokens.cream,
        elevation: 0,
        title: const Text('Speech model', style: AppTextStyles.uiTitle),
        iconTheme: const IconThemeData(color: ColorTokens.ink),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          children: <Widget>[
            const Text(
              'Whisper runs locally on your Mac. Pick a model — bigger means '
              'more accurate but slower and larger to download.',
              style: TextStyle(
                fontSize: 12,
                color: ColorTokens.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (_error != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF0E8),
                  border: Border.all(color: const Color(0xFFF4C8B1)),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Text(
                  'Download failed: $_error',
                  style: const TextStyle(fontSize: 12, color: ColorTokens.ink),
                ),
              ),
              const SizedBox(height: Spacing.md),
            ],
            for (final model in ModelCatalog.all) ...<Widget>[
              _ModelRow(
                model: model,
                downloaded: _isDownloaded(model),
                active: _isActive(model),
                downloading: _activeDownload?.id == model.id,
                progress: _activeDownload?.id == model.id ? _progress : null,
                onDownload: () => _startDownload(model),
                onCancel: _cancel,
                onSelect: () =>
                    widget.onModelSelected(_pathFor(model)),
                onDelete: () => _deleteModel(model),
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.downloaded,
    required this.active,
    required this.downloading,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
    required this.onSelect,
    required this.onDelete,
  });

  final WhisperModel model;
  final bool downloaded;
  final bool active;
  final bool downloading;
  final DownloadProgress? progress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: ColorTokens.paper,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: active ? ColorTokens.accent : ColorTokens.lineSoft,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      model.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatBytes(model.approximateBytes)} · ${model.filename}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ColorTokens.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              _trailing(),
            ],
          ),
          if (downloading) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            LinearProgressIndicator(
              value: progress?.fraction,
              minHeight: 4,
              backgroundColor: ColorTokens.accentSoft,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(ColorTokens.accent),
            ),
            const SizedBox(height: 4),
            Text(
              _progressLabel(progress),
              style: const TextStyle(fontSize: 10, color: ColorTokens.inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trailing() {
    if (downloading) {
      return TextButton(
        onPressed: onCancel,
        child: const Text('Cancel'),
      );
    }
    if (active) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_circle, color: ColorTokens.accent, size: 18),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete file',
            icon: const Icon(Icons.delete_outline,
                color: ColorTokens.inkSoft, size: 18),
          ),
        ],
      );
    }
    if (downloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextButton(onPressed: onSelect, child: const Text('Use')),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete file',
            icon: const Icon(Icons.delete_outline,
                color: ColorTokens.inkSoft, size: 18),
          ),
        ],
      );
    }
    return FilledButton(
      onPressed: onDownload,
      child: const Text('Download'),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
  final mb = bytes / (1024 * 1024);
  if (mb < 1024) return '${mb.toStringAsFixed(0)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

String _progressLabel(DownloadProgress? p) {
  if (p == null) return '';
  final got = _formatBytes(p.bytesReceived);
  final total = p.totalBytes == null ? '?' : _formatBytes(p.totalBytes!);
  final percent = p.fraction == null
      ? ''
      : ' · ${(p.fraction! * 100).toStringAsFixed(0)}%';
  return '$got / $total$percent';
}

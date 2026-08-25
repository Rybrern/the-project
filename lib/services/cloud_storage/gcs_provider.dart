import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'cloud_storage_provider.dart';

/// Implementación de Google Cloud Storage
class GCSProvider implements CloudStorageProvider {
  late CloudStorageConfig _config;
  bool _initialized = false;

  // Simulamos cliente GCS
  final Map<String, Uint8List> _storage = {};
  final Map<String, CloudStorageFileInfo> _fileInfo = {};

  @override
  String get name => 'Google Cloud Storage';

  @override
  String get description => 'Google Cloud Storage provider with CDN integration';

  @override
  Future<void> initialize(CloudStorageConfig config) async {
    if (config.bucket == null || config.bucket!.isEmpty) {
      throw ArgumentError('GCS bucket must be specified');
    }

    _config = config;
    _initialized = true;
    debugPrint('GCSProvider initialized for bucket: ${config.bucket}');
  }

  @override
  Future<CloudStorageResult> uploadFile(
    String fileName,
    Uint8List data, {
    Map<String, String>? metadata,
  }) async {
    _checkInitialized();

    try {
      final path = '${_config.prefix}/$fileName';

      // Simular compresión
      final compressedSize = (data.length * (_config.compressionLevel / 100)).toInt();

      _storage[path] = data;
      _fileInfo[path] = CloudStorageFileInfo(
        name: fileName,
        size: compressedSize,
        lastModified: DateTime.now(),
        contentType: _guessContentType(fileName),
        etag: _generateETag(data),
        metadata: metadata,
      );

      // URL con posible CDN
      final cdnUrl = _config.region == 'cdn'
          ? 'https://cdn.googleapis.com/${_config.bucket}/$path'
          : 'https://storage.googleapis.com/${_config.bucket}/$path';

      final url = _config.publicRead ? cdnUrl : '$cdnUrl?private=true';

      debugPrint('GCS: Uploaded $fileName (${compressedSize}B)');

      return CloudStorageResult(
        success: true,
        url: url,
        metadata: {
          'bucket': _config.bucket,
          'path': path,
          'size': compressedSize,
          'original_size': data.length,
          'project': 'gcp-project-id',
          'storage_class': 'STANDARD',
        },
      );
    } catch (e) {
      return CloudStorageResult(
        success: false,
        url: '',
        error: 'GCS upload failed: $e',
      );
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileName) async {
    _checkInitialized();

    try {
      final path = '${_config.prefix}/$fileName';
      final data = _storage[path];

      if (data == null) {
        debugPrint('GCS: File not found: $fileName');
        return null;
      }

      debugPrint('GCS: Downloaded $fileName');
      return data;
    } catch (e) {
      debugPrint('GCS: Download error: $e');
      return null;
    }
  }

  @override
  Future<bool> deleteFile(String fileName) async {
    _checkInitialized();

    try {
      final path = '${_config.prefix}/$fileName';
      final existed = _storage.remove(path) != null;
      _fileInfo.remove(path);

      if (existed) {
        debugPrint('GCS: Deleted $fileName');
      }

      return existed;
    } catch (e) {
      debugPrint('GCS: Delete error: $e');
      return false;
    }
  }

  @override
  Future<bool> fileExists(String fileName) async {
    _checkInitialized();

    final path = '${_config.prefix}/$fileName';
    return _storage.containsKey(path);
  }

  @override
  Future<List<String>> listFiles({
    String? prefix,
    int? limit,
  }) async {
    _checkInitialized();

    try {
      final searchPrefix = prefix ?? _config.prefix;
      var files = _storage.keys
          .where((key) => key.startsWith(searchPrefix))
          .map((key) => key.replaceFirst('${_config.prefix}/', ''))
          .toList();

      if (limit != null && files.length > limit) {
        files = files.sublist(0, limit);
      }

      debugPrint('GCS: Listed ${files.length} files');
      return files;
    } catch (e) {
      debugPrint('GCS: List error: $e');
      return [];
    }
  }

  @override
  Future<String?> getPublicUrl(String fileName) async {
    _checkInitialized();

    if (!_config.publicRead) {
      return null;
    }

    final path = '${_config.prefix}/$fileName';
    if (!await fileExists(fileName)) {
      return null;
    }

    return 'https://storage.googleapis.com/${_config.bucket}/$path';
  }

  @override
  Future<CloudStorageFileInfo?> getFileInfo(String fileName) async {
    _checkInitialized();

    final path = '${_config.prefix}/$fileName';
    return _fileInfo[path];
  }

  @override
  Future<String?> getTemporaryUrl(
    String fileName, {
    Duration validity = const Duration(hours: 24),
  }) async {
    _checkInitialized();

    if (!await fileExists(fileName)) {
      return null;
    }

    final path = '${_config.prefix}/$fileName';
    final expiryTime = DateTime.now().add(validity);

    // Generar URL presignada simulada
    return 'https://storage.googleapis.com/${_config.bucket}/$path'
        '?X-Goog-Expires=${validity.inSeconds}'
        '&X-Goog-Date=${expiryTime.toIso8601String()}';
  }

  @override
  Future<void> close() async {
    _initialized = false;
    debugPrint('GCSProvider closed');
  }

  /// Obtener estadísticas de uso
  Future<CloudStorageStats> getStats() async {
    _checkInitialized();

    final files = _fileInfo.values.toList();
    if (files.isEmpty) {
      return CloudStorageStats(
        totalFiles: 0,
        totalSize: 0,
        avgFileSize: 0,
      );
    }

    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final avgSize = totalSize / files.length;

    return CloudStorageStats(
      totalFiles: files.length,
      totalSize: totalSize,
      avgFileSize: avgSize,
      oldestFile: files.map((f) => f.lastModified).reduce((a, b) => a.isBefore(b) ? a : b),
      newestFile: files.map((f) => f.lastModified).reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// Habilitación de Cloud CDN
  Future<bool> enableCloudCDN() async {
    _checkInitialized();
    debugPrint('GCS: Cloud CDN enabled for ${_config.bucket}');
    return true;
  }

  /// Configurar Object Lifecycle
  Future<bool> setObjectLifecycle({
    required int daysToDelete,
    required int daysToArchive,
  }) async {
    _checkInitialized();
    debugPrint(
      'GCS: Lifecycle set - archive after $daysToArchive days, delete after $daysToDelete days',
    );
    return true;
  }

  /// Enable Access Control Lists
  Future<bool> enableAccessControl() async {
    _checkInitialized();
    debugPrint('GCS: Access Control enabled');
    return true;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('GCSProvider not initialized. Call initialize() first.');
    }
  }

  String _guessContentType(String fileName) {
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (fileName.endsWith('.png')) {
      return 'image/png';
    }
    if (fileName.endsWith('.gif')) {
      return 'image/gif';
    }
    if (fileName.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }

  String _generateETag(Uint8List data) {
    return 'etag-${data.length}-${DateTime.now().millisecondsSinceEpoch}';
  }
}

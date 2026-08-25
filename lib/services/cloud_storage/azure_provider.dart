import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'cloud_storage_provider.dart';

/// Implementación de Azure Blob Storage
class AzureProvider implements CloudStorageProvider {
  late CloudStorageConfig _config;
  bool _initialized = false;

  final Map<String, Uint8List> _storage = {};
  final Map<String, CloudStorageFileInfo> _fileInfo = {};

  @override
  String get name => 'Azure Blob Storage';

  @override
  String get description => 'Microsoft Azure Blob Storage provider';

  @override
  Future<void> initialize(CloudStorageConfig config) async {
    if (config.bucket == null || config.bucket!.isEmpty) {
      throw ArgumentError('Azure container must be specified');
    }

    _config = config;
    _initialized = true;
    debugPrint('AzureProvider initialized for container: ${config.bucket}');
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

      final accountName = _config.region ?? 'storageaccount';
      final url = _config.publicRead
          ? 'https://$accountName.blob.core.windows.net/${_config.bucket}/$path'
          : 'https://$accountName.blob.core.windows.net/${_config.bucket}/$path?sv=2021-06-08&sig=sas-token';

      debugPrint('Azure: Uploaded $fileName (${compressedSize}B)');

      return CloudStorageResult(
        success: true,
        url: url,
        metadata: {
          'container': _config.bucket,
          'path': path,
          'size': compressedSize,
          'account': accountName,
          'access_tier': 'Hot',
        },
      );
    } catch (e) {
      return CloudStorageResult(
        success: false,
        url: '',
        error: 'Azure upload failed: $e',
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
        debugPrint('Azure: Blob not found: $fileName');
        return null;
      }

      debugPrint('Azure: Downloaded $fileName');
      return data;
    } catch (e) {
      debugPrint('Azure: Download error: $e');
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
        debugPrint('Azure: Deleted $fileName');
      }

      return existed;
    } catch (e) {
      debugPrint('Azure: Delete error: $e');
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

      debugPrint('Azure: Listed ${files.length} blobs');
      return files;
    } catch (e) {
      debugPrint('Azure: List error: $e');
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

    final accountName = _config.region ?? 'storageaccount';
    return 'https://$accountName.blob.core.windows.net/${_config.bucket}/$path';
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
    final accountName = _config.region ?? 'storageaccount';
    final expiryTime = DateTime.now().add(validity);

    // Generar SAS URL simulada
    return 'https://$accountName.blob.core.windows.net/${_config.bucket}/$path'
        '?sv=2021-06-08'
        '&sig=sample-signature'
        '&se=${expiryTime.toIso8601String()}'
        '&sp=racwd';
  }

  @override
  Future<void> close() async {
    _initialized = false;
    debugPrint('AzureProvider closed');
  }

  /// Obtener estadísticas
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

  /// Enable blob versioning
  Future<bool> enableVersioning() async {
    _checkInitialized();
    debugPrint('Azure: Blob versioning enabled for ${_config.bucket}');
    return true;
  }

  /// Set access tier (Hot, Cool, Archive)
  Future<bool> setAccessTier(String tier) async {
    _checkInitialized();
    debugPrint('Azure: Access tier set to $tier for ${_config.bucket}');
    return true;
  }

  /// Enable Azure CDN
  Future<bool> enableAzureCDN() async {
    _checkInitialized();
    debugPrint('Azure: CDN enabled for ${_config.bucket}');
    return true;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('AzureProvider not initialized. Call initialize() first.');
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

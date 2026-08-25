import 'package:flutter/foundation.dart';
import 'cloud_storage_provider.dart';
import 'aws_s3_provider.dart';
import 'gcs_provider.dart';
import 'azure_provider.dart';

/// Registro centralizado de proveedores cloud storage
class CloudStorageRegistry {
  static final CloudStorageRegistry _instance = CloudStorageRegistry._internal();

  final Map<String, CloudStorageProvider> _providers = {};
  final Map<String, CloudStorageConfig> _configs = {};
  CloudStorageProvider? _active;

  factory CloudStorageRegistry() {
    return _instance;
  }

  CloudStorageRegistry._internal() {
    _initializeDefaultProviders();
  }

  /// Inicializa proveedores por defecto
  void _initializeDefaultProviders() {
    _providers['aws'] = AWSS3Provider();
    _providers['gcs'] = GCSProvider();
    _providers['azure'] = AzureProvider();

    debugPrint('CloudStorageRegistry initialized with 3 default providers');
  }

  /// Registra un nuevo proveedor
  void registerProvider(String name, CloudStorageProvider provider) {
    _providers[name] = provider;
    debugPrint('CloudStorageRegistry: Registered provider "$name"');
  }

  /// Obtiene un proveedor
  CloudStorageProvider? getProvider(String name) {
    return _providers[name];
  }

  /// Activa un proveedor
  Future<void> activateProvider(String name, CloudStorageConfig config) async {
    final provider = _providers[name];
    if (provider == null) {
      throw ArgumentError('Provider "$name" not found');
    }

    await provider.initialize(config);
    _active = provider;
    _configs[name] = config;

    debugPrint('CloudStorageRegistry: Activated provider "$name"');
  }

  /// Obtiene el proveedor activo
  CloudStorageProvider? getActiveProvider() {
    return _active;
  }

  /// Obtiene la configuración de un proveedor
  CloudStorageConfig? getConfig(String name) {
    return _configs[name];
  }

  /// Lista todos los proveedores disponibles
  List<String> getAvailableProviders() {
    return _providers.keys.toList();
  }

  /// Lista información de todos los proveedores
  Map<String, String> getProviderInfo() {
    return {
      for (final entry in _providers.entries) entry.key: entry.value.description,
    };
  }

  /// Cambia el proveedor activo
  Future<void> switchProvider(String name, CloudStorageConfig config) async {
    // Cerrar el proveedor anterior si existe
    if (_active != null) {
      await _active!.close();
    }

    // Activar nuevo proveedor
    await activateProvider(name, config);
  }

  /// Cierra el proveedor activo
  Future<void> closeActiveProvider() async {
    if (_active != null) {
      await _active!.close();
      _active = null;
      debugPrint('CloudStorageRegistry: Active provider closed');
    }
  }

  /// Obtiene estadísticas del proveedor activo
  Future<CloudStorageStats?> getActiveProviderStats() async {
    if (_active == null) {
      return null;
    }

    final info = await _active!.getFileInfo('');
    if (info == null) {
      // Contar manualmente
      final files = await _active!.listFiles();
      if (files.isEmpty) {
        return CloudStorageStats(
          totalFiles: 0,
          totalSize: 0,
          avgFileSize: 0,
        );
      }

      int totalSize = 0;
      DateTime? oldest, newest;

      for (final file in files) {
        final fileInfo = await _active!.getFileInfo(file);
        if (fileInfo != null) {
          totalSize += fileInfo.size;
          if (oldest == null || fileInfo.lastModified.isBefore(oldest)) {
            oldest = fileInfo.lastModified;
          }
          if (newest == null || fileInfo.lastModified.isAfter(newest)) {
            newest = fileInfo.lastModified;
          }
        }
      }

      return CloudStorageStats(
        totalFiles: files.length,
        totalSize: totalSize,
        avgFileSize: files.isNotEmpty ? totalSize / files.length : 0,
        oldestFile: oldest,
        newestFile: newest,
      );
    }

    return null;
  }

  /// Test de conectividad con el proveedor activo
  Future<bool> testConnection() async {
    if (_active == null) {
      return false;
    }

    try {
      // Crear archivo de test
      final testData = 'test'.codeUnits;
      final result = await _active!.uploadFile(
        '.cloud-storage-test',
        Uint8List.fromList(testData),
      );

      if (!result.success) {
        return false;
      }

      // Eliminar archivo de test
      return await _active!.deleteFile('.cloud-storage-test');
    } catch (e) {
      debugPrint('CloudStorageRegistry: Connection test failed: $e');
      return false;
    }
  }

  /// Sincroniza archivo desde proveedor A a proveedor B
  Future<bool> syncBetweenProviders(
    String sourceProviderName,
    String targetProviderName,
    String fileName,
  ) async {
    final source = _providers[sourceProviderName];
    final target = _providers[targetProviderName];

    if (source == null || target == null) {
      return false;
    }

    try {
      final data = await source.downloadFile(fileName);
      if (data == null) {
        return false;
      }

      final result = await target.uploadFile(fileName, data);
      return result.success;
    } catch (e) {
      debugPrint('CloudStorageRegistry: Sync failed: $e');
      return false;
    }
  }

  /// Obtiene el precio estimado (simulado)
  CloudStoragePricing estimatePricing(CloudStorageStats stats) {
    // Precios aproximados por GB (2026)
    const s3PricePerGB = 0.023;
    const gcsPricePerGB = 0.020;
    const azurePricePerGB = 0.018;

    final sizeGB = stats.totalSize / (1024 * 1024 * 1024);

    return CloudStoragePricing(
      aws: sizeGB * s3PricePerGB,
      gcs: sizeGB * gcsPricePerGB,
      azure: sizeGB * azurePricePerGB,
      sizeGB: sizeGB,
    );
  }

  /// Limpia recursos
  Future<void> dispose() async {
    await closeActiveProvider();
    _providers.clear();
    _configs.clear();
    debugPrint('CloudStorageRegistry: Disposed');
  }
}

/// Estimación de precios mensuales
class CloudStoragePricing {
  const CloudStoragePricing({
    required this.aws,
    required this.gcs,
    required this.azure,
    required this.sizeGB,
  });

  final double aws;
  final double gcs;
  final double azure;
  final double sizeGB;

  /// Proveedor más económico
  String getCheapestProvider() {
    if (aws <= gcs && aws <= azure) return 'AWS S3';
    if (gcs <= aws && gcs <= azure) return 'Google Cloud Storage';
    return 'Azure Blob Storage';
  }

  /// Ahorro usando el proveedor más barato
  double getSavings() {
    final max = [aws, gcs, azure].reduce((a, b) => a > b ? a : b);
    final min = [aws, gcs, azure].reduce((a, b) => a < b ? a : b);
    return max - min;
  }
}

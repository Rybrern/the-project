import 'dart:typed_data';

/// Resultado de operación cloud storage
class CloudStorageResult {
  const CloudStorageResult({
    required this.success,
    required this.url,
    this.error,
    this.metadata,
  });

  /// Si la operación fue exitosa
  final bool success;

  /// URL del recurso almacenado
  final String url;

  /// Mensaje de error si falló
  final String? error;

  /// Metadatos adicionales (bucket, path, size, etc)
  final Map<String, dynamic>? metadata;

  @override
  String toString() => 'CloudStorageResult(success=$success, url=$url, error=$error)';
}

/// Configuración de proveedor cloud
class CloudStorageConfig {
  const CloudStorageConfig({
    required this.provider,
    required this.credentials,
    this.bucket,
    this.region,
    this.prefix = 'wallpapers',
    this.publicRead = true,
    this.autoSync = true,
    this.compressionLevel = 85,
  });

  /// Tipo de proveedor (aws, gcs, azure, etc)
  final String provider;

  /// Credenciales (API key, access key, etc)
  final String credentials;

  /// Bucket/container name
  final String? bucket;

  /// Región (aws, gcs)
  final String? region;

  /// Prefijo de ruta
  final String prefix;

  /// Si los archivos son públicos
  final bool publicRead;

  /// Auto-sync de wallpapers a cloud
  final bool autoSync;

  /// Nivel de compresión (0-100)
  final int compressionLevel;
}

/// Interfaz base para proveedores de almacenamiento cloud
abstract class CloudStorageProvider {
  /// Nombre del proveedor
  String get name;

  /// Descripción
  String get description;

  /// Inicializa la conexión
  Future<void> initialize(CloudStorageConfig config);

  /// Sube un archivo
  Future<CloudStorageResult> uploadFile(
    String fileName,
    Uint8List data, {
    Map<String, String>? metadata,
  });

  /// Descarga un archivo
  Future<Uint8List?> downloadFile(String fileName);

  /// Elimina un archivo
  Future<bool> deleteFile(String fileName);

  /// Verifica si un archivo existe
  Future<bool> fileExists(String fileName);

  /// Lista archivos en el bucket
  Future<List<String>> listFiles({
    String? prefix,
    int? limit,
  });

  /// Obtiene URL pública de un archivo
  Future<String?> getPublicUrl(String fileName);

  /// Obtiene información del archivo
  Future<CloudStorageFileInfo?> getFileInfo(String fileName);

  /// Genera URL de descarga temporal
  Future<String?> getTemporaryUrl(
    String fileName, {
    Duration validity = const Duration(hours: 24),
  });

  /// Cierra la conexión
  Future<void> close();
}

/// Información de archivo en cloud storage
class CloudStorageFileInfo {
  const CloudStorageFileInfo({
    required this.name,
    required this.size,
    required this.lastModified,
    this.contentType,
    this.etag,
    this.metadata,
  });

  /// Nombre del archivo
  final String name;

  /// Tamaño en bytes
  final int size;

  /// Última modificación
  final DateTime lastModified;

  /// Content type (mime)
  final String? contentType;

  /// ETag para comparación
  final String? etag;

  /// Metadatos custom
  final Map<String, dynamic>? metadata;
}

/// Estadísticas de almacenamiento cloud
class CloudStorageStats {
  const CloudStorageStats({
    required this.totalFiles,
    required this.totalSize,
    required this.avgFileSize,
    this.oldestFile,
    this.newestFile,
    this.downloadCount = 0,
    this.bandwidthUsed = 0,
  });

  /// Total de archivos
  final int totalFiles;

  /// Tamaño total (bytes)
  final int totalSize;

  /// Tamaño promedio (bytes)
  final double avgFileSize;

  /// Archivo más antiguo
  final DateTime? oldestFile;

  /// Archivo más nuevo
  final DateTime? newestFile;

  /// Descargas este mes
  final int downloadCount;

  /// Ancho de banda usado (bytes)
  final int bandwidthUsed;

  /// Total size in MB
  double get totalSizeMB => totalSize / (1024 * 1024);

  /// Avg file size in MB
  double get avgFileSizeMB => avgFileSize / (1024 * 1024);
}

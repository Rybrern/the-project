/// Configuración del procesamiento por lotes.
class BatchConfig {
  const BatchConfig({
    this.batchSize = 50,
    this.maxConcurrentDownloads = 3,
    this.maxConcurrentAnalysis = 2,
    this.downloadTimeoutSeconds = 30,
    this.minImageWidth = 1920,
    this.minImageHeight = 1080,
    this.maxNsfwScore = 0.3, // 0-1: rechaza si > este valor
    this.minQualityScore = 0.5,
    this.retryAttempts = 3,
    this.retryDelayMs = 1000,
    this.enableLocalStorage = true,
    this.storageBasePath = 'wallpapers',
  });

  /// Cantidad de candidatos a procesar por lote
  final int batchSize;

  /// Máximo de descargas simultáneas
  final int maxConcurrentDownloads;

  /// Máximo de análisis simultáneos (NSFW, quality, etc.)
  final int maxConcurrentAnalysis;

  /// Timeout para descargas (segundos)
  final int downloadTimeoutSeconds;

  /// Resolución mínima aceptable
  final int minImageWidth;
  final int minImageHeight;

  /// Umbral de score NSFW (0-1, mayor = más NSFW)
  /// Rechaza si score > este valor
  final double maxNsfwScore;

  /// Score mínimo de calidad requerido (0-1)
  final double minQualityScore;

  /// Intentos de reintento en caso de error
  final int retryAttempts;

  /// Delay entre reintentos (ms)
  final int retryDelayMs;

  /// Si se guardan imágenes localmente
  final bool enableLocalStorage;

  /// Ruta base para almacenamiento local
  final String storageBasePath;

  BatchConfig copyWith({
    int? batchSize,
    int? maxConcurrentDownloads,
    int? maxConcurrentAnalysis,
    int? downloadTimeoutSeconds,
    int? minImageWidth,
    int? minImageHeight,
    double? maxNsfwScore,
    double? minQualityScore,
    int? retryAttempts,
    int? retryDelayMs,
    bool? enableLocalStorage,
    String? storageBasePath,
  }) {
    return BatchConfig(
      batchSize: batchSize ?? this.batchSize,
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      maxConcurrentAnalysis: maxConcurrentAnalysis ?? this.maxConcurrentAnalysis,
      downloadTimeoutSeconds: downloadTimeoutSeconds ?? this.downloadTimeoutSeconds,
      minImageWidth: minImageWidth ?? this.minImageWidth,
      minImageHeight: minImageHeight ?? this.minImageHeight,
      maxNsfwScore: maxNsfwScore ?? this.maxNsfwScore,
      minQualityScore: minQualityScore ?? this.minQualityScore,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelayMs: retryDelayMs ?? this.retryDelayMs,
      enableLocalStorage: enableLocalStorage ?? this.enableLocalStorage,
      storageBasePath: storageBasePath ?? this.storageBasePath,
    );
  }
}

/// Configuraciones predefinidas para diferentes escenarios
class BatchConfigs {
  static const BatchConfig conservative = BatchConfig(
    batchSize: 20,
    maxConcurrentDownloads: 1,
    maxConcurrentAnalysis: 1,
    maxNsfwScore: 0.1, // Muy estricto
  );

  static const BatchConfig balanced = BatchConfig(
    batchSize: 50,
    maxConcurrentDownloads: 3,
    maxConcurrentAnalysis: 2,
    maxNsfwScore: 0.3,
  );

  static const BatchConfig aggressive = BatchConfig(
    batchSize: 100,
    maxConcurrentDownloads: 5,
    maxConcurrentAnalysis: 3,
    maxNsfwScore: 0.5,
  );
}

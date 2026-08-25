class ProcessingRecord {
  const ProcessingRecord({
    required this.id,
    required this.sourceUrl,
    required this.status,
    required this.processedAt,
    required this.processingTimeMs,
    this.sourceId,
    this.wallpaperId,
    this.rejectionReason,
    this.metadata,
  });

  /// ID único del registro
  final String id;

  /// URL de donde se obtuvo el candidato
  final String sourceUrl;

  /// ID en la fuente original (ej: ID de Wallhaven)
  final String? sourceId;

  /// ID del wallpaper si fue aceptado
  final String? wallpaperId;

  /// 'processed' | 'rejected' | 'duplicate' | 'error'
  final String status;

  /// Motivo del rechazo (si aplica)
  final String? rejectionReason;

  /// Metadatos adicionales
  final Map<String, dynamic>? metadata;

  /// Cuándo se procesó
  final DateTime processedAt;

  /// Tiempo de procesamiento en ms
  final int processingTimeMs;

  /// Retorna true si el candidato fue aceptado
  bool get isAccepted => status == 'processed' && wallpaperId != null;

  /// Retorna true si fue rechazado
  bool get isRejected => status == 'rejected' || status == 'error' || status == 'duplicate';
}

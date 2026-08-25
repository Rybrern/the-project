/// Modelo para un trabajo de batch processing
class BatchJob {
  BatchJob({
    required this.id,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.status = 'pending',
    this.totalCandidates = 0,
    this.processed = 0,
    this.accepted = 0,
    this.rejected = 0,
    this.errors = 0,
  });

  final String id;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;

  /// 'pending' | 'running' | 'paused' | 'completed' | 'failed'
  String status;

  /// Estadísticas
  int totalCandidates;
  int processed;
  int accepted;
  int rejected;
  int errors;

  /// Calcula progreso (0.0 - 1.0)
  double get progress =>
      totalCandidates == 0 ? 0.0 : processed / totalCandidates;

  /// Calcula tasa de aceptación
  double get acceptanceRate =>
      processed == 0 ? 0.0 : accepted / processed;

  /// Duración total del job
  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Velocidad promedio (items por segundo)
  double get itemsPerSecond {
    final dur = duration;
    if (dur == null || dur.inSeconds == 0) return 0;
    return processed / dur.inSeconds;
  }

  /// Tiempo estimado de finalización
  Duration? get estimatedTimeRemaining {
    if (totalCandidates == 0 || processed == 0) return null;
    final remaining = totalCandidates - processed;
    final speed = itemsPerSecond;
    if (speed == 0) return null;
    return Duration(seconds: (remaining / speed).toInt());
  }
}

/// Evento de progreso durante el batch processing
class BatchProgressEvent {
  BatchProgressEvent({
    required this.stage,
    required this.processed,
    required this.total,
    this.message,
    this.currentItem,
    this.details,
  });

  /// 'fetch' | 'download' | 'dedup' | 'nsfw' | 'quality' | 'classification' | 'storage'
  final String stage;

  final int processed;
  final int total;
  final String? message;
  final String? currentItem;
  final Map<String, dynamic>? details;

  double get progress => total == 0 ? 0.0 : processed / total;

  @override
  String toString() {
    return 'BatchProgressEvent($stage: $processed/$total - $message)';
  }
}

/// Resultado de un candidato procesado
class BatchCandidateResult {
  BatchCandidateResult({
    required this.candidateUrl,
    required this.status,
    required this.processingTimeMs,
    this.wallpaperId,
    this.rejectionReason,
    this.metadata,
  });

  final String candidateUrl;
  final String status; // 'accepted' | 'rejected' | 'error'
  final int processingTimeMs;

  /// ID del wallpaper si fue aceptado
  final String? wallpaperId;

  /// Motivo del rechazo
  final String? rejectionReason;

  /// Metadatos adicionales del procesamiento
  final Map<String, dynamic>? metadata;

  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isError => status == 'error';
}

/// Reporte final del batch
class BatchReport {
  BatchReport({
    required this.jobId,
    required this.startTime,
    required this.endTime,
    required this.totalCandidates,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.errorCount,
    this.results = const [],
  });

  final String jobId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalCandidates;
  final int acceptedCount;
  final int rejectedCount;
  final int errorCount;
  final List<BatchCandidateResult> results;

  Duration get duration => endTime.difference(startTime);

  double get acceptanceRate =>
      totalCandidates == 0 ? 0.0 : acceptedCount / totalCandidates;

  double get errorRate =>
      totalCandidates == 0 ? 0.0 : errorCount / totalCandidates;

  double get itemsPerSecond {
    final seconds = duration.inSeconds;
    if (seconds == 0) return 0;
    return totalCandidates / seconds;
  }

  Map<String, int> getRejectionSummary() {
    final summary = <String, int>{};
    for (final result in results) {
      if (result.isRejected) {
        final reason = result.rejectionReason ?? 'unknown';
        summary[reason] = (summary[reason] ?? 0) + 1;
      }
    }
    return summary;
  }

  @override
  String toString() {
    return '''
BatchReport($jobId):
  Duration: ${duration.inSeconds}s
  Total: $totalCandidates | Accepted: $acceptedCount | Rejected: $rejectedCount | Errors: $errorCount
  Acceptance Rate: ${(acceptanceRate * 100).toStringAsFixed(1)}%
  Speed: ${itemsPerSecond.toStringAsFixed(2)} items/s
''';
  }
}

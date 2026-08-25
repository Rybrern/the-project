import 'dart:typed_data';

import '../batch_config.dart';

/// Interfaz base para los stages del pipeline de procesamiento.
/// Cada stage es responsable de una parte del proceso.
abstract class PipelineStage {
  String get name;
  String get description;

  /// Ejecuta el stage
  /// Retorna lista de candidatos procesados para el siguiente stage
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  );
}

/// Candidato en procesamiento a través del pipeline
class PipelineCandidate {
  PipelineCandidate({
    required this.url,
    required this.sourceId,
    required this.source,
    this.data,
    this.metadata = const {},
    this.rejectionReasons = const [],
  });

  /// URL original del candidato
  final String url;

  /// ID en la fuente original
  final String sourceId;

  /// Fuente (wallhaven, pixabay, etc.)
  final String source;

  /// Datos de la imagen (después de descarga)
  Uint8List? data;

  /// Metadatos acumulados
  Map<String, dynamic> metadata;

  /// Razones de rechazo acumuladas
  List<String> rejectionReasons;

  /// Retorna true si el candidato ha sido rechazado
  bool get isRejected => rejectionReasons.isNotEmpty;

  /// Rechaza el candidato con una razón
  void reject(String reason) {
    rejectionReasons.add(reason);
  }

  /// Actualiza metadatos
  void updateMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  /// Obtiene un valor de metadatos
  dynamic getMetadata(String key) => metadata[key];
}

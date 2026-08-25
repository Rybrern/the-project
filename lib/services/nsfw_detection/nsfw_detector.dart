import 'dart:typed_data';

/// Resultado de detección NSFW
class NSFWDetectionResult {
  const NSFWDetectionResult({
    required this.score, // 0.0 - 1.0 (mayor = más NSFW)
    required this.isNSFW,
    required this.confidence, // 0.0 - 1.0 (confianza en el resultado)
    this.method,
    this.details,
  });

  /// Score NSFW (0.0 = seguro, 1.0 = definidamente NSFW)
  final double score;

  /// Clasificación binaria según umbral
  final bool isNSFW;

  /// Qué tan seguro está el detector (0.0 - 1.0)
  final double confidence;

  /// Método usado: 'metadata', 'local_model', 'api'
  final String? method;

  /// Detalles adicionales (categorías detectadas, etc.)
  final Map<String, dynamic>? details;

  @override
  String toString() => 'NSFWDetectionResult(score=$score, isNSFW=$isNSFW, confidence=$confidence, method=$method)';
}

/// Interfaz base para detectores NSFW
abstract class NSFWDetector {
  /// Nombre del detector
  String get name;

  /// Descripción
  String get description;

  /// Prioridad (mayor = se ejecuta primero)
  int get priority => 0;

  /// Detecta NSFW en una imagen
  Future<NSFWDetectionResult?> detect(
    Uint8List imageData, {
    Map<String, dynamic>? metadata,
  });

  /// Inicializa el detector (cargar modelos, etc.)
  Future<void> initialize() async {}

  /// Limpia recursos
  Future<void> dispose() async {}
}

/// Configuración de NSFW detection
class NSFWConfig {
  const NSFWConfig({
    this.enableMetadataDetection = true,
    this.enableLocalModel = true,
    this.enableAPIDetection = false,
    this.nsfwThreshold = 0.3, // Score máximo aceptable
    this.confidenceThreshold = 0.5, // Confianza mínima requerida
    this.defaultAction = 'reject', // 'reject' | 'manual_review' | 'accept'
  });

  /// Usa análisis de metadatos
  final bool enableMetadataDetection;

  /// Usa modelo local
  final bool enableLocalModel;

  /// Usa API externa
  final bool enableAPIDetection;

  /// Score máximo de NSFW aceptable (>= rechaza)
  final double nsfwThreshold;

  /// Confianza mínima requerida para decidir
  final double confidenceThreshold;

  /// Acción si resultado es ambiguo
  final String defaultAction;

  NSFWConfig copyWith({
    bool? enableMetadataDetection,
    bool? enableLocalModel,
    bool? enableAPIDetection,
    double? nsfwThreshold,
    double? confidenceThreshold,
    String? defaultAction,
  }) {
    return NSFWConfig(
      enableMetadataDetection: enableMetadataDetection ?? this.enableMetadataDetection,
      enableLocalModel: enableLocalModel ?? this.enableLocalModel,
      enableAPIDetection: enableAPIDetection ?? this.enableAPIDetection,
      nsfwThreshold: nsfwThreshold ?? this.nsfwThreshold,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      defaultAction: defaultAction ?? this.defaultAction,
    );
  }
}

/// Configuraciones predefinidas
class NSFWConfigs {
  static const NSFWConfig strict = NSFWConfig(
    enableMetadataDetection: true,
    enableLocalModel: true,
    enableAPIDetection: false,
    nsfwThreshold: 0.1, // Muy permisivo (acepta si < 0.1)
    confidenceThreshold: 0.7,
    defaultAction: 'reject',
  );

  static const NSFWConfig balanced = NSFWConfig(
    enableMetadataDetection: true,
    enableLocalModel: true,
    enableAPIDetection: false,
    nsfwThreshold: 0.3,
    confidenceThreshold: 0.5,
    defaultAction: 'reject',
  );

  static const NSFWConfig permissive = NSFWConfig(
    enableMetadataDetection: true,
    enableLocalModel: false,
    enableAPIDetection: false,
    nsfwThreshold: 0.7,
    confidenceThreshold: 0.3,
    defaultAction: 'accept',
  );
}

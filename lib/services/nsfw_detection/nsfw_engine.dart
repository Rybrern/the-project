import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'nsfw_detector.dart';

/// Orquestador central de detección NSFW.
/// Coordina múltiples detectores y toma una decisión final basada en scores y confianza.
class NSFWEngine {
  NSFWEngine({required this.config});

  final NSFWConfig config;
  final List<NSFWDetector> _detectors = [];

  /// Registra un detector
  void addDetector(NSFWDetector detector) {
    _detectors.add(detector);
    // Ordena por prioridad (mayor primero)
    _detectors.sort((a, b) => b.priority.compareTo(a.priority));
    debugPrint('NSFWEngine: Registered detector "${detector.name}" (priority=${detector.priority})');
  }

  /// Inicializa todos los detectores
  Future<void> initialize() async {
    for (final detector in _detectors) {
      try {
        await detector.initialize();
        debugPrint('NSFWEngine: Initialized detector "${detector.name}"');
      } catch (e) {
        debugPrint('NSFWEngine: Failed to initialize detector "${detector.name}": $e');
      }
    }
  }

  /// Detecta NSFW en una imagen usando múltiples detectores
  Future<NSFWDetectionResult> detect(
    Uint8List imageData, {
    Map<String, dynamic>? metadata,
  }) async {
    if (_detectors.isEmpty) {
      debugPrint('NSFWEngine: No detectors registered');
      return NSFWDetectionResult(
        score: 0.5,
        isNSFW: false,
        confidence: 0.0,
        details: {'error': 'No detectors available'},
      );
    }

    final results = <NSFWDetectionResult>[];

    // Ejecuta detectores en orden de prioridad
    for (final detector in _detectors) {
      try {
        final result = await detector.detect(imageData, metadata: metadata);
        if (result != null) {
          results.add(result);
          debugPrint('NSFWEngine: Detector "${detector.name}" returned ${result.score}');

          // Si encuentra resultado con alta confianza, puede salir temprano
          if (result.confidence > 0.9) {
            break;
          }
        }
      } catch (e) {
        debugPrint('NSFWEngine: Error in detector "${detector.name}": $e');
      }
    }

    // Toma decisión basada en resultados
    return _makeFinalDecision(results);
  }

  /// Toma decisión final combinando resultados de todos los detectores
  NSFWDetectionResult _makeFinalDecision(List<NSFWDetectionResult> results) {
    if (results.isEmpty) {
      return NSFWDetectionResult(
        score: 0.0,
        isNSFW: false,
        confidence: 0.0,
        details: {'error': 'No results from detectors'},
      );
    }

    // Estrategia: promedio ponderado por confianza
    double weightedScore = 0.0;
    double totalWeight = 0.0;

    for (final result in results) {
      weightedScore += result.score * result.confidence;
      totalWeight += result.confidence;
    }

    final finalScore = totalWeight > 0 ? weightedScore / totalWeight : 0.5;
    final avgConfidence = results.fold<double>(0, (a, b) => a + b.confidence) / results.length;

    // Determina si es NSFW
    final isNSFW = finalScore > config.nsfwThreshold;

    // Determina acción final
    String action = config.defaultAction;
    if (avgConfidence > config.confidenceThreshold) {
      action = isNSFW ? 'reject' : 'accept';
    } else {
      // Baja confianza: depende de defaultAction
      action = config.defaultAction;
    }

    debugPrint(
      'NSFWEngine: Final decision - Score=$finalScore, Confidence=$avgConfidence, Action=$action',
    );

    return NSFWDetectionResult(
      score: finalScore,
      isNSFW: isNSFW,
      confidence: avgConfidence,
      method: 'ensemble',
      details: {
        'detectors_count': results.length,
        'detector_results': results.map((r) => {'method': r.method, 'score': r.score}).toList(),
        'action': action,
        'threshold': config.nsfwThreshold,
      },
    );
  }

  /// Limpia recursos
  Future<void> dispose() async {
    for (final detector in _detectors) {
      try {
        await detector.dispose();
      } catch (e) {
        debugPrint('NSFWEngine: Error disposing detector: $e');
      }
    }
    _detectors.clear();
  }

  /// Obtiene estadísticas
  Map<String, dynamic> getStatistics() {
    return {
      'detectors_registered': _detectors.length,
      'detectors': _detectors.map((d) => {'name': d.name, 'priority': d.priority}).toList(),
      'config': {
        'nsfw_threshold': config.nsfwThreshold,
        'confidence_threshold': config.confidenceThreshold,
        'default_action': config.defaultAction,
      },
    };
  }
}

import 'package:flutter/foundation.dart';

import '../admin/admin_tools.dart';
import '../batch_processing/batch_processing.dart';

/// Cliente API para administración remota de batch processing.
/// Permite controlar ingesta de fondos desde aplicaciones externas.
class BatchAPIClient {
  BatchAPIClient({required this.batchCommands});

  final BatchCommands batchCommands;

  /// Inicia procesamiento de categoría
  /// Retorna job ID para tracking
  Future<Map<String, dynamic>> startBatchJob(
    String categoryId, {
    String? configProfile,
  }) async {
    debugPrint('BatchAPIClient: Starting batch job for $categoryId');

    final config = _getConfigByProfile(configProfile);

    try {
      final report = await batchCommands.processCategory(
        categoryId,
        config: config,
      );

      return {
        'status': 'success',
        'job_id': _generateJobId(),
        'category': categoryId,
        'results': {
          'total_candidates': report.totalCandidates,
          'accepted': report.acceptedCount,
          'rejected': report.rejectedCount,
          'acceptance_rate': report.acceptanceRate,
          'duration_seconds': report.duration.inSeconds,
        },
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'category': categoryId,
      };
    }
  }

  /// Obtiene estado de un job
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    // En una implementación real, consultaría una BD de jobs
    return {
      'job_id': jobId,
      'status': 'completed', // o 'running', 'queued', 'failed'
      'progress': 100,
      'current_stage': 'storage',
    };
  }

  /// Obtiene estadísticas del sistema
  Future<Map<String, dynamic>> getSystemStats() async {
    return batchCommands.getStats();
  }

  /// Obtiene análisis de rechazos
  Future<Map<String, dynamic>> getRejectionAnalysis() async {
    return batchCommands.analyzeRejections();
  }

  /// Obtiene recomendaciones
  Future<List<String>> getRecommendations() async {
    return batchCommands.getRecommendations();
  }

  /// Ejecuta limpieza de mantenimiento
  Future<Map<String, dynamic>> runMaintenance() async {
    try {
      final deleted = await batchCommands.cleanupOrphanedHashes();
      return {
        'status': 'success',
        'orphaned_hashes_deleted': deleted,
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Obtiene configuración disponible
  Map<String, dynamic> getAvailableConfigs() {
    return {
      'conservative': {
        'batch_size': 20,
        'max_concurrent_downloads': 1,
        'max_nsfw_score': 0.1,
        'description': 'Maximum safety, slower processing',
      },
      'balanced': {
        'batch_size': 50,
        'max_concurrent_downloads': 3,
        'max_nsfw_score': 0.3,
        'description': 'Recommended for production',
      },
      'aggressive': {
        'batch_size': 100,
        'max_concurrent_downloads': 5,
        'max_nsfw_score': 0.5,
        'description': 'Higher volume, more lenient filtering',
      },
    };
  }

  /// Obtiene el perfil de configuración
  BatchConfig _getConfigByProfile(String? profile) {
    return switch (profile) {
      'conservative' => BatchConfigs.conservative,
      'aggressive' => BatchConfigs.aggressive,
      _ => BatchConfigs.balanced,
    };
  }

  /// Genera un ID de job único
  String _generateJobId() {
    return 'job_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Modelo para solicitud de API
class BatchJobRequest {
  const BatchJobRequest({
    required this.categoryId,
    this.configProfile = 'balanced',
    this.maxWallpapers,
    this.tags,
  });

  final String categoryId;
  final String configProfile;
  final int? maxWallpapers;
  final List<String>? tags;

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'config_profile': configProfile,
      'max_wallpapers': maxWallpapers,
      'tags': tags,
    };
  }
}

/// Modelo para respuesta de API
class BatchJobResponse {
  const BatchJobResponse({
    required this.jobId,
    required this.status,
    required this.results,
    this.error,
  });

  final String jobId;
  final String status; // 'success', 'error', 'running'
  final Map<String, dynamic> results;
  final String? error;

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'status': status,
      'results': results,
      if (error != null) 'error': error,
    };
  }
}

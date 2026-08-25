import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../database/daos/daos.dart';
import '../discovery/discovery.dart';
import 'batch_config.dart';
import 'batch_models.dart';
import 'download_manager.dart';
import 'pipeline/pipeline_stage.dart';
import 'pipeline/fetch_stage.dart';
import 'pipeline/download_stage.dart';
import 'pipeline/dedup_stage.dart';
import 'pipeline/quality_stage.dart';
import 'pipeline/nsfw_stage.dart';
import 'pipeline/classification_stage.dart';
import 'pipeline/storage_stage.dart';
import '../nsfw_detection/nsfw_detection.dart';

typedef BatchProgressCallback = void Function(BatchProgressEvent event);

/// Orquestador principal del batch processing.
/// Coordina todo el pipeline: discovery → download → validation → storage.
class BatchProcessor {
  BatchProcessor({
    required this.discoveryEngine,
    required this.config,
    required this.wallpaperDAO,
    required this.hashRegistryDAO,
    required this.processingRecordDAO,
    required this.rejectedCandidateDAO,
    this.nsfwEngine,
  });

  final DiscoveryEngine discoveryEngine;
  final BatchConfig config;
  final WallpaperDAO wallpaperDAO;
  final HashRegistryDAO hashRegistryDAO;
  final ProcessingRecordDAO processingRecordDAO;
  final RejectedCandidateDAO rejectedCandidateDAO;
  final NSFWEngine? nsfwEngine;

  /// Cola de callbacks para progreso
  final List<BatchProgressCallback> _observers = [];

  late final List<PipelineStage> _pipeline;

  void _initializePipeline() {
    _pipeline = [
      FetchStage(),
      DownloadStage(
        downloadManager: DownloadManager(
          maxConcurrent: config.maxConcurrentDownloads,
          timeoutSeconds: config.downloadTimeoutSeconds,
          retryAttempts: config.retryAttempts,
          retryDelayMs: config.retryDelayMs,
        ),
      ),
      DedupStage(hashRegistry: hashRegistryDAO),
      QualityStage(),
      // Agrega NSFWStage si está disponible
      if (nsfwEngine != null) NSFWStage(nsfwEngine: nsfwEngine!),
      ClassificationStage(),
      StorageStage(
        wallpaperDAO: wallpaperDAO,
        hashRegistryDAO: hashRegistryDAO,
        processingRecordDAO: processingRecordDAO,
        rejectedCandidateDAO: rejectedCandidateDAO,
      ),
    ];
  }

  /// Registra un observer para recibir actualizaciones de progreso
  void addObserver(BatchProgressCallback callback) {
    _observers.add(callback);
  }

  /// Ejecuta el batch processing completo
  Future<BatchReport> process(List<String> categoryIds) async {
    _initializePipeline();

    final jobId = _generateJobId();
    final startTime = DateTime.now();

    debugPrint('BatchProcessor: Starting job $jobId for ${categoryIds.length} categories');

    try {
      // Descubre candidatos
      _notifyProgress('discovery', 0, categoryIds.length, 'Discovering candidates...');
      final wallpapers = await discoveryEngine.discoverByCategories(
        categoryIds,
        limitPerCategory: config.batchSize,
      );

      // Convierte a candidatos del pipeline
      final candidates = wallpapers
          .map(
            (wp) => PipelineCandidate(
              url: wp.fullUrl,
              sourceId: wp.sourceId ?? wp.id,
              source: wp.source ?? 'unknown',
              metadata: {
                'author': wp.author,
                'tags': wp.tags,
                'original_url': wp.originalUrl,
              },
            ),
          )
          .toList();

      // Ejecuta el pipeline
      var processedCandidates = candidates;
      for (var i = 0; i < _pipeline.length; i++) {
        final stage = _pipeline[i];
        _notifyProgress(
          stage.name,
          0,
          processedCandidates.length,
          'Running ${stage.description}...',
        );

        final startStage = DateTime.now();
        processedCandidates = await stage.execute(processedCandidates, config);
        final stageDuration = DateTime.now().difference(startStage);

        debugPrint('BatchProcessor: Stage "${stage.name}" completed in ${stageDuration.inSeconds}s');
      }

      final endTime = DateTime.now();

      // Genera reporte
      final acceptedCount = processedCandidates.where((c) => !c.isRejected).length;
      final rejectedCount = candidates.length - acceptedCount;

      final report = BatchReport(
        jobId: jobId,
        startTime: startTime,
        endTime: endTime,
        totalCandidates: candidates.length,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
        errorCount: 0,
      );

      debugPrint('BatchProcessor: Job $jobId completed. ${report.toString()}');

      _notifyProgress(
        'completion',
        candidates.length,
        candidates.length,
        'Batch processing completed',
      );

      return report;
    } catch (e) {
      debugPrint('BatchProcessor: Error during job $jobId: $e');
      rethrow;
    }
  }

  /// Notifica a todos los observers del progreso
  void _notifyProgress(
    String stage,
    int processed,
    int total,
    String message,
  ) {
    final event = BatchProgressEvent(
      stage: stage,
      processed: processed,
      total: total,
      message: message,
    );

    for (final observer in _observers) {
      try {
        observer(event);
      } catch (e) {
        debugPrint('BatchProcessor: Error notifying observer: $e');
      }
    }
  }

  /// Genera un ID único para el job
  String _generateJobId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    return 'batch_$id';
  }
}

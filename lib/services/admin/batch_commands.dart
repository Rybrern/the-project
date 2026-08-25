import '../../database/daos/daos.dart';
import '../../models/default_categories.dart';
import '../batch_processing/batch_processing.dart';
import '../discovery/discovery.dart';
import '../nsfw_detection/nsfw_detection.dart';
import 'batch_logger.dart';
import 'rejection_analyzer.dart';

/// Comandos administrativos para batch processing.
/// Permite ejecutar trabajos de ingesta masiva desde la aplicación.
class BatchCommands {
  BatchCommands({
    required this.discoveryEngine,
    required this.wallpaperDAO,
    required this.hashRegistryDAO,
    required this.processingRecordDAO,
    required this.rejectedCandidateDAO,
    this.nsfwEngine,
  });

  final DiscoveryEngine discoveryEngine;
  final WallpaperDAO wallpaperDAO;
  final HashRegistryDAO hashRegistryDAO;
  final ProcessingRecordDAO processingRecordDAO;
  final RejectedCandidateDAO rejectedCandidateDAO;
  final NSFWEngine? nsfwEngine;

  late final BatchJobLogger _logger;

  /// Procesa una categoría con configuración personalizada
  Future<BatchReport> processCategory(
    String categoryId, {
    BatchConfig? config,
    void Function(BatchProgressEvent)? onProgress,
  }) async {
    config ??= BatchConfigs.balanced;
    _logger = BatchJobLogger('batch_${DateTime.now().millisecondsSinceEpoch}');

    _logger.log('Starting batch process for category: $categoryId');

    try {
      final processor = BatchProcessor(
        discoveryEngine: discoveryEngine,
        config: config,
        wallpaperDAO: wallpaperDAO,
        hashRegistryDAO: hashRegistryDAO,
        processingRecordDAO: processingRecordDAO,
        rejectedCandidateDAO: rejectedCandidateDAO,
        nsfwEngine: nsfwEngine,
      );

      if (onProgress != null) {
        processor.addObserver(onProgress);
      }

      // Agrega logging automático
      processor.addObserver((event) {
        _logger.log('${event.stage}: ${event.processed}/${event.total} - ${event.message}');
      });

      final report = await processor.process([categoryId]);
      _logger.log('Batch completed: ${report.acceptedCount} accepted, ${report.rejectedCount} rejected');

      return report;
    } catch (e) {
      _logger.log('Error during batch: $e', level: 'ERROR');
      rethrow;
    }
  }

  /// Procesa múltiples categorías
  Future<Map<String, BatchReport>> processBatch(
    List<String> categoryIds, {
    BatchConfig? config,
    void Function(BatchProgressEvent)? onProgress,
  }) async {
    config ??= BatchConfigs.balanced;
    _logger = BatchJobLogger('batch_${DateTime.now().millisecondsSinceEpoch}');

    _logger.log('Starting batch process for ${categoryIds.length} categories');

    final reports = <String, BatchReport>{};

    for (final categoryId in categoryIds) {
      try {
        _logger.log('Processing category: $categoryId');
        final report = await processCategory(categoryId, config: config, onProgress: onProgress);
        reports[categoryId] = report;
      } catch (e) {
        _logger.log('Failed to process category $categoryId: $e', level: 'ERROR');
      }
    }

    return reports;
  }

  /// Procesa todos los deportes (categoría popular)
  Future<BatchReport> processSports({
    BatchConfig? config,
    void Function(BatchProgressEvent)? onProgress,
  }) async {
    _logger.log('Processing all sports categories');

    // Busca todas las subcategorías de deportes
    final sportsCategory = defaultCategoriesHierarchy.firstWhere(
      (c) => c.id == 'deportes',
      orElse: () => throw Exception('Sports category not found'),
    );

    final sportIds = sportsCategory.subcategories?.map((s) => s.id).toList() ?? [];

    return (await processBatch(sportIds, config: config, onProgress: onProgress)).values.isNotEmpty
        ? (await processBatch(sportIds, config: config, onProgress: onProgress)).values.first
        : throw Exception('No sports processed');
  }

  /// Reprocessa rechazados (intenta nuevamente con configuración diferente)
  Future<BatchReport> reprocessRejected({
    int limit = 100,
    BatchConfig? config,
    void Function(BatchProgressEvent)? onProgress,
  }) async {
    config ??= BatchConfigs.balanced;
    _logger = BatchJobLogger('reprocess_${DateTime.now().millisecondsSinceEpoch}');

    _logger.log('Reprocessing up to $limit rejected candidates');

    final rejectedRecords = await rejectedCandidateDAO.getRecentRejections(limit: limit);

    final urlsToReprocess = rejectedRecords
        .map((r) => r['source_url'] as String)
        .toSet()
        .take(limit)
        .toList();

    _logger.log('Found ${urlsToReprocess.length} unique URLs to reprocess');

    // TODO: Implementar re-descarga y reprocesamiento
    // Por ahora solo registramos la intención

    return BatchReport(
      jobId: _logger.jobId,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      totalCandidates: urlsToReprocess.length,
      acceptedCount: 0,
      rejectedCount: 0,
      errorCount: urlsToReprocess.length,
    );
  }

  /// Obtiene estadísticas del sistema
  Future<Map<String, dynamic>> getStats() async {
    final totalWallpapers = await wallpaperDAO.getTotalCount();
    final processingStats = await processingRecordDAO.getStatistics();
    final hashStats = await hashRegistryDAO.getStatistics();
    final rejectionStats = await rejectedCandidateDAO.getRejectionStats();

    return {
      'wallpapers': {
        'total': totalWallpapers,
      },
      'processing': processingStats,
      'deduplication': hashStats,
      'rejections': rejectionStats,
      'total_processed': (processingStats['processed'] ?? 0),
      'total_rejected': rejectionStats.values.fold(0, (a, b) => a + b),
    };
  }

  /// Obtiene análisis de rechazos
  Future<Map<String, dynamic>> analyzeRejections() async {
    final analyzer = RejectionAnalyzer(rejectedCandidateDAO: rejectedCandidateDAO);
    return analyzer.analyzeRejections();
  }

  /// Obtiene recomendaciones
  Future<List<String>> getRecommendations() async {
    final analyzer = RejectionAnalyzer(rejectedCandidateDAO: rejectedCandidateDAO);
    return analyzer.getRecommendations();
  }

  /// Limpia hashes huérfanos (mantenimiento)
  Future<int> cleanupOrphanedHashes() async {
    _logger.log('Cleaning up orphaned hashes');
    final deleted = await hashRegistryDAO.cleanupOrphanedHashes();
    _logger.log('Deleted $deleted orphaned hashes');
    return deleted;
  }

  /// Obtiene el logger del último job
  BatchJobLogger get lastLogger => _logger;
}

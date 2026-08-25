/// EJEMPLO DE USO: Sistema Completo de Ingesta Masiva de Wallpapers
///
/// Este archivo muestra cómo usar todos los componentes implementados
/// para ejecutar un batch processing completo.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../config/wallhaven_config.dart';
import '../config/media_api_config.dart';
import '../database/app_database.dart';
import '../database/daos/daos.dart';
import '../models/default_categories.dart';
import 'discovery/discovery.dart';
import 'providers/providers.dart';
import 'batch_processing/batch_processing.dart';
import 'nsfw_detection/nsfw_detection.dart';
import 'admin/admin_tools.dart';
import 'unified_wallpaper_service.dart';

/// Ejemplo completo: Ingesta de 500 wallpapers de deportes
void ingestionExample() async {
  debugPrint('=== WALLPAPER INGESTION SYSTEM EXAMPLE ===\n');

  // 1. INICIALIZA COMPONENTES BÁSICOS
  debugPrint('Step 1: Initializing database...');
  final db = AppDatabase();
  final database = await db.database;

  // 2. INICIALIZA DAOs
  debugPrint('Step 2: Initializing DAOs...');
  final wallpaperDAO = WallpaperDAO(db);
  final processingRecordDAO = ProcessingRecordDAO(db);
  final hashRegistryDAO = HashRegistryDAO(db);
  final rejectedCandidateDAO = RejectedCandidateDAO(db);
  final categoryHierarchyDAO = CategoryHierarchyDAO(db);

  // 3. INICIALIZA PROVIDERS Y DISCOVERY
  debugPrint('Step 3: Initializing discovery engine...');
  final registry = ProviderRegistry();
  registry.initializeDefaults(
    wallhavenApiKey: wallhavenApiKey,
    pixabayApiKey: pixabayApiKey,
    unsplashAccessKey: unsplashAccessKey,
  );

  final discoveryEngine = DiscoveryEngine(registry: registry);
  discoveryEngine.initialize(defaultCategoriesHierarchy);

  // 4. INICIALIZA NSFW DETECTION
  debugPrint('Step 4: Initializing NSFW detection...');
  final nsfwEngine = NSFWEngine(config: NSFWConfigs.balanced);

  // Registra detectores
  final metadataDetector = MetadataDetector();
  final localModelDetector = LocalModelDetector(enabled: true);

  nsfwEngine.addDetector(metadataDetector);
  nsfwEngine.addDetector(localModelDetector);
  await nsfwEngine.initialize();

  // 5. CONFIGURA BATCH PROCESSING
  debugPrint('Step 5: Configuring batch processor...');
  final batchConfig = BatchConfigs.balanced.copyWith(
    batchSize: 50,
    maxConcurrentDownloads: 3,
    maxNsfwScore: 0.3,
  );

  // 6. CREA COMANDOS ADMINISTRATIVOS
  debugPrint('Step 6: Setting up admin commands...');
  final batchCommands = BatchCommands(
    discoveryEngine: discoveryEngine,
    wallpaperDAO: wallpaperDAO,
    hashRegistryDAO: hashRegistryDAO,
    processingRecordDAO: processingRecordDAO,
    rejectedCandidateDAO: rejectedCandidateDAO,
    nsfwEngine: nsfwEngine,
  );

  // 7. EJECUTA BATCH PROCESSING PARA DEPORTES
  debugPrint('\nStep 7: Processing sports category...\n');

  final stopwatch = Stopwatch()..start();

  final report = await batchCommands.processCategory(
    'deportes',
    config: batchConfig,
    onProgress: (event) {
      debugPrint('Progress: ${event.stage} - ${event.processed}/${event.total}');
    },
  );

  stopwatch.stop();

  // 8. MUESTRA RESULTADOS
  debugPrint('\n=== RESULTS ===');
  debugPrint('Total Processed: ${report.totalCandidates}');
  debugPrint('Accepted: ${report.acceptedCount}');
  debugPrint('Rejected: ${report.rejectedCount}');
  debugPrint('Acceptance Rate: ${(report.acceptanceRate * 100).toStringAsFixed(2)}%');
  debugPrint('Speed: ${report.itemsPerSecond.toStringAsFixed(2)} items/sec');
  debugPrint('Duration: ${stopwatch.elapsed.inSeconds}s');

  // 9. ANÁLISIS DE RECHAZOS
  debugPrint('\nStep 8: Analyzing rejections...');
  final rejectionAnalysis = await batchCommands.analyzeRejections();
  debugPrint('Rejection Analysis: $rejectionAnalysis');

  // 10. OBTIENE RECOMENDACIONES
  debugPrint('\nStep 9: Getting recommendations...');
  final recommendations = await batchCommands.getRecommendations();
  for (final rec in recommendations) {
    debugPrint('  - $rec');
  }

  // 11. ESTADÍSTICAS FINALES
  debugPrint('\nStep 10: Final statistics...');
  final stats = await batchCommands.getStats();
  debugPrint('Stats: $stats');

  // 12. OBTIENE LOGS
  debugPrint('\nStep 11: Exporting logs...');
  final logContent = batchCommands.lastLogger.generateReport(report);
  debugPrint(logContent);

  debugPrint('\n=== INGESTION COMPLETE ===');
}

/// Ejemplo simplificado: Procesar una sola categoría
void simpleIngestionExample() async {
  // Setup básico (igual que arriba, pero sin todos los detalles)
  final db = AppDatabase();
  await db.database;

  final wallpaperDAO = WallpaperDAO(db);
  final processingRecordDAO = ProcessingRecordDAO(db);
  final hashRegistryDAO = HashRegistryDAO(db);
  final rejectedCandidateDAO = RejectedCandidateDAO(db);

  final registry = ProviderRegistry();
  registry.initializeDefaults(
    wallhavenApiKey: wallhavenApiKey,
    pixabayApiKey: pixabayApiKey,
    unsplashAccessKey: unsplashAccessKey,
  );

  final discoveryEngine = DiscoveryEngine(registry: registry);
  discoveryEngine.initialize(defaultCategoriesHierarchy);

  final nsfwEngine = NSFWEngine(config: NSFWConfigs.balanced);
  nsfwEngine.addDetector(MetadataDetector());
  await nsfwEngine.initialize();

  // Ejecutar
  final batchCommands = BatchCommands(
    discoveryEngine: discoveryEngine,
    wallpaperDAO: wallpaperDAO,
    hashRegistryDAO: hashRegistryDAO,
    processingRecordDAO: processingRecordDAO,
    rejectedCandidateDAO: rejectedCandidateDAO,
    nsfwEngine: nsfwEngine,
  );

  // Procesa solo fútbol
  final report = await batchCommands.processCategory('futbol');
  debugPrint('Processed ${report.acceptedCount} wallpapers');
}

/// Ejemplo: Usar el servicio unificado (compatible con UI existente)
void unifiedServiceExample() async {
  // El UnifiedWallpaperService mantiene compatibilidad con la UI existente
  // mientras expone nuevas capacidades
  final service = UnifiedWallpaperService(
    wallhavenApiKey: wallhavenApiKey,
    pixabayApiKey: pixabayApiKey,
  );

  // Usa capacidades legacy
  final categories = await service.fetchCategories();

  // O usa nuevas capacidades
  final wallpapers = await service.discoverByCategory('futbol');

  // O descubre múltiples categorías
  final sportsWallpapers = await service.discoverByCategories(['futbol', 'basquetbol']);

  debugPrint('Found ${sportsWallpapers.length} wallpapers');
}

import 'package:flutter_test/flutter_test.dart';
import '../database/app_database.dart';
import '../database/daos/wallpaper_dao.dart';
import '../database/daos/category_hierarchy_dao.dart';
import '../database/daos/hash_registry_dao.dart';
import '../models/wallpaper.dart';
import '../models/category_hierarchy.dart';
import '../services/batch_processing/batch_config.dart';
import '../services/discovery/discovery_engine.dart';
import '../services/providers/provider_registry.dart';
import '../services/nsfw_detection/metadata_detector.dart';
import '../services/nsfw_detection/nsfw_detector.dart';
import '../services/nsfw_detection/nsfw_engine.dart';
import '../services/deduplication/perceptual_hash.dart';

void main() {
  late AppDatabase database;
  late WallpaperDAO wallpaperDAO;
  late CategoryHierarchyDAO categoryDAO;
  late HashRegistryDAO hashDAO;
  late ProviderRegistry providerRegistry;
  late DiscoveryEngine discoveryEngine;

  setUpAll(() async {
    database = AppDatabase();
    wallpaperDAO = WallpaperDAO(database);
    categoryDAO = CategoryHierarchyDAO(database);
    hashDAO = HashRegistryDAO(database);
    providerRegistry = ProviderRegistry();
    discoveryEngine = DiscoveryEngine(registry: providerRegistry);
  });

  tearDownAll(() async {
    await database.close();
  });

  group('Database Layer Tests', () {
    test('Wallpaper DAO insertion and retrieval', () async {
      final wallpaper = Wallpaper(
        id: 'test_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        fullUrl: 'https://example.com/full.jpg',
        author: 'Test Author',
        category: 'test',
        aspectRatio: 16 / 9,
        source: 'test_source',
        sourceId: 'test_id',
        fileHash: 'abc123',
        perceptualHash: '1010101010',
        nsfwScore: 0.1,
        qualityScore: 0.85,
        primaryCategory: 'test',
        subcategory: 'subcategory',
        tags: ['test'],
        processingStatus: 'completed',
        processedAt: DateTime.now(),
      );

      await wallpaperDAO.insert(wallpaper);
      final retrieved = await wallpaperDAO.getById('test_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.author, 'Test Author');
      expect(retrieved.nsfwScore, 0.1);
    });

    test('Hash Registry operations', () async {
      await hashDAO.register(
        hash: 'test_hash_1',
        wallpaperId: 'wp_1',
        source: 'test_source',
      );

      await hashDAO.register(
        hash: 'test_hash_2',
        wallpaperId: 'wp_2',
        source: 'test_source',
      );

      final exists = await hashDAO.existsHash('test_hash_1');
      expect(exists, true);

      final notExists = await hashDAO.existsHash('nonexistent');
      expect(notExists, false);
    });

    test('Category Hierarchy creation', () async {
      final category = CategoryHierarchy(
        id: 'sports',
        name: 'Sports',
        emoji: '⚽',
        description: 'Sports category',
        priority: 1,
      );

      await categoryDAO.insert(category);
      final retrieved = await categoryDAO.getById('sports');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Sports');
    });
  });

  group('NSFW Detection Tests', () {
    test('Metadata detector initialization', () {
      final detector = MetadataDetector();

      expect(detector.name, 'metadata');
      expect(detector.priority, greaterThan(0));
    });

    test('Metadata detector detects NSFW keywords', () async {
      final detector = MetadataDetector();
      await detector.initialize();

      final imageData = List<int>.filled(100, 255);
      final nsfwResult = await detector.detect(
        imageData as dynamic,
        metadata: {'title': 'nude adult content'},
      );

      expect(nsfwResult, isNotNull);
      expect(nsfwResult!.score, greaterThan(0.0));
    });

    test('Metadata detector respects safe keywords', () async {
      final detector = MetadataDetector();
      await detector.initialize();

      final imageData = List<int>.filled(100, 255);
      final safeResult = await detector.detect(
        imageData as dynamic,
        metadata: {'title': 'beautiful cartoon art illustration'},
      );

      expect(safeResult, isNotNull);
      expect(safeResult!.score, greaterThanOrEqualTo(0.0));
    });

    test('NSFW Engine initialization', () {
      final config = NSFWConfigs.balanced;

      expect(config.nsfwThreshold, greaterThan(0.0));
      expect(config.nsfwThreshold, lessThanOrEqualTo(1.0));
    });
  });

  group('Deduplication Tests', () {
    test('Perceptual hash generation', () async {
      final generator = PerceptualHashGenerator();

      // Simula datos mínimos de imagen
      final imageData = List<int>.filled(100, 255);
      final hash = await generator.generateHash(imageData as dynamic);

      expect(hash.isNotEmpty, true);
    });

    test('Perceptual hash comparison - identical', () {
      final comparator = PerceptualHashComparator();

      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101010';

      final distance = PerceptualHashComparator.hammingDistance(hash1, hash2);
      expect(distance, 0);

      final similar = PerceptualHashComparator.isSimilar(hash1, hash2);
      expect(similar, true);
    });

    test('Perceptual hash comparison - similar', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101011';

      final distance = PerceptualHashComparator.hammingDistance(hash1, hash2);
      expect(distance, 1);
    });

    test('Hamming distance calculation', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1110101010101010101010101010101010101010101010101010101010101010';

      final distance = PerceptualHashComparator.hammingDistance(hash1, hash2);
      expect(distance, 1);
    });

    test('Similarity percentage calculation', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101010';

      final percent = PerceptualHashComparator.similarityPercentage(hash1, hash2);
      expect(percent, 100.0);
    });
  });

  group('Batch Configuration Tests', () {
    test('Default batch config', () {
      final config = const BatchConfig();

      expect(config.batchSize, 50);
      expect(config.maxNsfwScore, 0.3);
      expect(config.minQualityScore, 0.5);
    });

    test('Custom batch config', () {
      final config = const BatchConfig(
        batchSize: 100,
        maxNsfwScore: 0.2,
        minQualityScore: 0.7,
      );

      expect(config.batchSize, 100);
      expect(config.maxNsfwScore, 0.2);
      expect(config.minQualityScore, 0.7);
    });
  });

  group('Discovery Engine Tests', () {
    test('Discovery engine initialization', () {
      discoveryEngine.initialize([]);
      expect(discoveryEngine, isNotNull);
    });

    test('Provider registry operations', () {
      final providers = providerRegistry.getEnabledProviders();
      expect(providers, isNotEmpty);
    });
  });

  group('Integration Tests', () {
    test('Complete NSFW + Database workflow', () async {
      // 1. Crear wallpaper de prueba
      final wallpaper = Wallpaper(
        id: 'integration_test_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        fullUrl: 'https://example.com/full.jpg',
        author: 'Test Author',
        category: 'test',
        aspectRatio: 16 / 9,
        source: 'test',
        sourceId: 'test_id',
        fileHash: 'test_hash',
        perceptualHash: '1010101010101010101010101010101010101010101010101010101010101010',
        nsfwScore: 0.2,
        qualityScore: 0.9,
        primaryCategory: 'test',
        subcategory: 'test',
        tags: ['test'],
        processingStatus: 'completed',
        processedAt: DateTime.now(),
      );

      // 2. Guardar en base de datos
      await wallpaperDAO.insert(wallpaper);

      // 3. Verificar existencia
      final retrieved = await wallpaperDAO.getById('integration_test_1');
      expect(retrieved, isNotNull);

      // 4. Registrar hash
      await hashDAO.register(
        hash: 'test_hash',
        wallpaperId: 'integration_test_1',
        source: 'test',
      );

      final hashExists = await hashDAO.existsHash('test_hash');
      expect(hashExists, true);

      // 5. Verificar NSFW score
      expect(retrieved!.nsfwScore, lessThan(0.5));
    });

    test('Deduplication + Database integration', () async {
      // 1. Generar hashes
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101010';

      // 2. Verificar similitud
      final similar = PerceptualHashComparator.isSimilar(hash1, hash2, threshold: 5);
      expect(similar, true);

      // 3. Registrar en hash registry
      await hashDAO.register(
        hash: 'dedup_test_1',
        wallpaperId: 'dedup_wp_1',
        source: 'test',
        perceptualHash: hash1,
      );

      final exists = await hashDAO.existsHash('dedup_test_1');
      expect(exists, true);
    });
  });
}

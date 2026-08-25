import 'package:flutter_test/flutter_test.dart';
import '../models/wallpaper.dart';
import '../models/category_hierarchy.dart';
import '../services/batch_processing/batch_config.dart';
import '../services/nsfw_detection/metadata_detector.dart';
import '../services/nsfw_detection/nsfw_detector.dart';
import '../services/deduplication/perceptual_hash.dart';
import '../services/discovery/discovery_engine.dart';
import '../services/providers/provider_registry.dart';

void main() {
  group('Compilation and Model Tests', () {
    test('Wallpaper model creation', () {
      final wallpaper = Wallpaper(
        id: 'test_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        fullUrl: 'https://example.com/full.jpg',
        author: 'Test Author',
        category: 'test',
        aspectRatio: 16 / 9,
        source: 'test',
        sourceId: 'test_id',
        fileHash: 'abc123',
        perceptualHash: '1010101010',
        nsfwScore: 0.1,
        qualityScore: 0.85,
        primaryCategory: 'sports',
        subcategory: 'football',
        tags: ['test', 'demo'],
        processingStatus: 'completed',
        processedAt: DateTime.now(),
      );

      expect(wallpaper.id, 'test_1');
      expect(wallpaper.author, 'Test Author');
      expect(wallpaper.nsfwScore, 0.1);
      expect(wallpaper.qualityScore, 0.85);
      expect(wallpaper.primaryCategory, 'sports');
      expect(wallpaper.source, 'test');
    });

    test('Wallpaper model copyWith functionality', () {
      final wallpaper1 = Wallpaper(
        id: 'test_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        fullUrl: 'https://example.com/full.jpg',
        author: 'Author A',
        category: 'test',
        aspectRatio: 16 / 9,
      );

      final wallpaper2 = wallpaper1.copyWith(author: 'Author B');

      expect(wallpaper1.author, 'Author A');
      expect(wallpaper2.author, 'Author B');
      expect(wallpaper1.id, wallpaper2.id);
    });

    test('CategoryHierarchy model creation', () {
      final category = CategoryHierarchy(
        id: 'sports',
        name: 'Sports',
        emoji: '⚽',
        description: 'Sports wallpapers',
        priority: 1,
      );

      expect(category.id, 'sports');
      expect(category.name, 'Sports');
      expect(category.emoji, '⚽');
    });

    test('CategoryHierarchy with subcategories', () {
      final subCategory = CategoryHierarchy(
        id: 'football',
        name: 'Football',
        emoji: '🏈',
        priority: 0,
      );

      final category = CategoryHierarchy(
        id: 'sports',
        name: 'Sports',
        emoji: '⚽',
        subcategories: [subCategory],
        priority: 1,
      );

      expect(category.subcategories, isNotNull);
      expect(category.subcategories!.length, 1);
      expect(category.subcategories!.first.name, 'Football');
    });
  });

  group('Configuration and NSFW Detection Tests', () {
    test('BatchConfig default values', () {
      final config = const BatchConfig();

      expect(config.batchSize, 50);
      expect(config.maxConcurrentDownloads, 3);
      expect(config.maxNsfwScore, 0.3);
      expect(config.minQualityScore, 0.5);
      expect(config.downloadTimeoutSeconds, 30);
      expect(config.minImageWidth, 1920);
      expect(config.minImageHeight, 1080);
    });

    test('BatchConfig custom values', () {
      final config = const BatchConfig(
        batchSize: 100,
        maxNsfwScore: 0.2,
        minQualityScore: 0.7,
      );

      expect(config.batchSize, 100);
      expect(config.maxNsfwScore, 0.2);
      expect(config.minQualityScore, 0.7);
    });

    test('NSFWConfigs presets exist', () {
      expect(NSFWConfigs.strict.nsfwThreshold, lessThan(NSFWConfigs.balanced.nsfwThreshold));
      expect(NSFWConfigs.balanced.nsfwThreshold, lessThan(NSFWConfigs.permissive.nsfwThreshold));
    });

    test('MetadataDetector properties', () {
      final detector = MetadataDetector();

      expect(detector.name, 'metadata');
      expect(detector.description, isNotEmpty);
      expect(detector.priority, greaterThan(0));
    });
  });

  group('Deduplication and Hash Tests', () {
    test('Perceptual hash comparison - identical hashes', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101010';

      final distance = PerceptualHashComparator.hammingDistance(hash1, hash2);
      expect(distance, 0);

      final similar = PerceptualHashComparator.isSimilar(hash1, hash2);
      expect(similar, true);
    });

    test('Perceptual hash comparison - different hashes', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '0101010101010101010101010101010101010101010101010101010101010101';

      final distance = PerceptualHashComparator.hammingDistance(hash1, hash2);
      expect(distance, 64); // Completamente opuesto

      final similar = PerceptualHashComparator.isSimilar(hash1, hash2, threshold: 5);
      expect(similar, false);
    });

    test('Hamming distance single bit difference', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101011';

      final distance = PerceptualHashComparator.hammingDistance(hash1, hash2);
      expect(distance, 1);
    });

    test('Similarity percentage - identical', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101010';

      final percent = PerceptualHashComparator.similarityPercentage(hash1, hash2);
      expect(percent, 100.0);
    });

    test('Similarity percentage - one bit difference', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101011';

      final percent = PerceptualHashComparator.similarityPercentage(hash1, hash2);
      expect(percent, greaterThan(98.0)); // 63/64 bits match
      expect(percent, lessThan(100.0));
    });

    test('Similarity threshold behavior', () {
      final hash1 = '1010101010101010101010101010101010101010101010101010101010101010';
      final hash2 = '1010101010101010101010101010101010101010101010101010101010101011';

      expect(PerceptualHashComparator.isSimilar(hash1, hash2, threshold: 0), false);
      expect(PerceptualHashComparator.isSimilar(hash1, hash2, threshold: 1), true);
      expect(PerceptualHashComparator.isSimilar(hash1, hash2, threshold: 5), true);
    });
  });

  group('Discovery Engine and Provider Tests', () {
    test('Discovery engine initialization', () {
      final registry = ProviderRegistry();
      final engine = DiscoveryEngine(registry: registry);

      expect(engine, isNotNull);
      expect(engine.maxConcurrentSearches, 3);
    });

    test('Discovery engine custom concurrency', () {
      final registry = ProviderRegistry();
      final engine = DiscoveryEngine(
        registry: registry,
        maxConcurrentSearches: 5,
      );

      expect(engine.maxConcurrentSearches, 5);
    });

    test('Provider registry creation', () {
      final registry = ProviderRegistry();

      expect(registry, isNotNull);
    });
  });

  group('Integration Tests', () {
    test('Complete workflow: Models + Config + Dedup', () {
      // 1. Crear wallpaper
      final wallpaper = Wallpaper(
        id: 'wp_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        fullUrl: 'https://example.com/full.jpg',
        author: 'Artist',
        category: 'nature',
        aspectRatio: 16 / 9,
        source: 'test',
        sourceId: 'src_123',
        fileHash: 'sha256_hash',
        perceptualHash: '1010101010101010101010101010101010101010101010101010101010101010',
        nsfwScore: 0.15,
        qualityScore: 0.9,
        primaryCategory: 'nature',
        subcategory: 'landscapes',
        tags: ['mountains', 'sunset'],
        processingStatus: 'accepted',
      );

      // 2. Validar propiedades
      expect(wallpaper.nsfwScore, lessThan(0.3)); // Debajo del threshold
      expect(wallpaper.qualityScore, greaterThan(0.5)); // Arriba del mínimo
      expect(wallpaper.source, 'test');

      // 3. Validar deduplicación
      final sameHash = PerceptualHashComparator.isSimilar(
        wallpaper.perceptualHash!,
        wallpaper.perceptualHash!,
      );
      expect(sameHash, true);

      // 4. Usar copyWith para actualizar
      final updated = wallpaper.copyWith(
        nsfwScore: 0.05,
        processingStatus: 'accepted',
      );

      expect(updated.nsfwScore, 0.05);
      expect(updated.id, wallpaper.id); // ID no cambia
    });

    test('Batch processing configuration selection', () {
      // Escenario 1: Conservative (menos aceptaciones)
      final conservative = const BatchConfig(
        batchSize: 10,
        maxNsfwScore: 0.1,
        minQualityScore: 0.8,
      );

      // Escenario 2: Balanced
      final balanced = const BatchConfig(
        batchSize: 50,
        maxNsfwScore: 0.3,
        minQualityScore: 0.5,
      );

      // Escenario 3: Aggressive (más aceptaciones)
      final aggressive = const BatchConfig(
        batchSize: 200,
        maxNsfwScore: 0.5,
        minQualityScore: 0.3,
      );

      expect(conservative.batchSize, lessThan(balanced.batchSize));
      expect(balanced.batchSize, lessThan(aggressive.batchSize));
      expect(conservative.maxNsfwScore, lessThan(balanced.maxNsfwScore));
      expect(balanced.maxNsfwScore, lessThan(aggressive.maxNsfwScore));
    });

    test('Multi-level category hierarchy', () {
      final players = CategoryHierarchy(
        id: 'football_players',
        name: 'Football Players',
        emoji: '👤',
        priority: 2,
      );

      final football = CategoryHierarchy(
        id: 'football',
        name: 'Football',
        emoji: '⚽',
        subcategories: [players],
        priority: 1,
      );

      final sports = CategoryHierarchy(
        id: 'sports',
        name: 'Sports',
        emoji: '🏆',
        subcategories: [football],
        priority: 0,
      );

      expect(sports.subcategories, isNotNull);
      expect(sports.subcategories!.length, 1);
      expect(sports.subcategories!.first.name, 'Football');
      expect(sports.subcategories!.first.subcategories, isNotNull);
      expect(sports.subcategories!.first.subcategories!.first.name, 'Football Players');
    });
  });
}

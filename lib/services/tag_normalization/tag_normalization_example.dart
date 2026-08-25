/// Example and Integration Guide for Phase 4: Tag Normalization and Entity Seeding
///
/// This file demonstrates how to use the tag normalization system in the wallpaper app.
///
/// Overview of the workflow:
/// 1. Images are discovered from APIs (OpenVerse, Unsplash, GIPHY, Pixabay)
/// 2. API returns tags: ["messi", "lionel messi", "leo messi", "messi10", "football"]
/// 3. TagNormalizer normalizes: ["messi", "lionel messi", "leo messi", "messi10", "football"]
///    → ["messi", "lionel messi", "messi", "messi10", "football"]
/// 4. Deduplicates to canonical forms
/// 5. Detects entity types (PERSON, SPORT, etc.)
/// 6. Seeds into database with confidence scores
/// 7. Creates aliases for fuzzy matching
/// 8. Future searches resolve through alias mapping

// ignore_for_file: unused_local_variable, dead_code

import 'package:flutter/foundation.dart';

import '../../database/app_database.dart';
import '../../models/wallpaper.dart';
import 'tag_normalizer.dart';
import 'tag_seeder.dart';
import 'tag_alias_service.dart';

/// Example 1: Basic text normalization
void exampleBasicNormalization() {
  final normalizer = TagNormalizer();

  // Normalize text with accent removal and lowercasing
  final result1 = normalizer.normalizeText('Lionel Messi');
  // Result: "lionel messi"

  final result2 = normalizer.normalizeText('Café');
  // Result: "cafe"

  final result3 = normalizer.normalizeText('São Paulo');
  // Result: "sao paulo"

  // Build canonical name from display name
  final canonical = normalizer.buildCanonicalName('Lionel Messi');
  // Result: "lionel-messi"

  debugPrint('Normalized: $result1, $result2, $result3');
  debugPrint('Canonical: $canonical');
}

/// Example 2: Extract and normalize tags from API response
void exampleExtractTags() {
  final normalizer = TagNormalizer();

  // Simulate tags from OpenVerse API
  final apiTags = [
    {'name': 'Lionel Messi'},
    {'name': 'messi'},
    {'name': 'Football'},
    {'name': 'Football'}, // Duplicate
  ];

  // Extract and normalize
  final normalized = normalizer.extractTags(apiTags);
  // Result: ["lionel messi", "messi", "football"]
  // (deduplicated and normalized)

  debugPrint('Extracted tags: $normalized');
}

/// Example 3: Fuzzy matching for similar tags
void exampleFuzzyMatching() {
  final normalizer = TagNormalizer();

  // Fuzzy match similar strings
  final score1 = normalizer.fuzzyMatchScore('messi', 'lionel messi');
  // Result: ~0.6

  final score2 = normalizer.fuzzyMatchScore('leo', 'leonel');
  // Result: ~0.85

  final score3 = normalizer.fuzzyMatchScore('cr7', 'cristiano ronaldo');
  // Result: ~0.4

  debugPrint('Fuzzy match scores: $score1, $score2, $score3');
}

/// Example 4: Tag type detection
void exampleTagTypeDetection() {
  final normalizer = TagNormalizer();

  // Detect if tag is likely a person
  final personLikelihood = normalizer.personNameLikelihood('lionel messi');
  // Result: 0.85 (high confidence it's a person)

  // Detect if it's a location
  final isLocation = normalizer.isLikelyLocation('barcelona');
  // Result: false (Barcelona is both location and team)

  // Detect if it's sports-related
  final isSports = normalizer.isLikelySports('formula 1');
  // Result: true

  debugPrint('Person likelihood: $personLikelihood');
  debugPrint('Is location: $isLocation, Is sports: $isSports');
}

/// Example 5: Seed tags from wallpaper
Future<void> exampleSeedTagsFromWallpaper(AppDatabase database) async {
  final seeder = TagSeeder(database);

  // Create a wallpaper with tags from API
  final wallpaper = Wallpaper(
    id: 'openverse_12345',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    fullUrl: 'https://example.com/full.jpg',
    author: 'John Doe',
    category: 'deportes',
    aspectRatio: 1.78,
    source: 'openverse',
    sourceId: '12345',
    tags: [
      'messi',
      'lionel messi',
      'football',
      'argentina',
    ],
  );

  // Seed tags from the wallpaper
  final success = await seeder.seedTagsFromImage(wallpaper);
  debugPrint('Tag seeding result: $success');

  // What happens:
  // 1. Tags are extracted and normalized
  // 2. Entity types are detected (PERSON, SPORT, LOCATION)
  // 3. Tags are inserted into database if new
  // 4. Aliases are created for original tag text
  // 5. Image-tag links are created with confidence=1.0 (API-provided)
}

/// Example 6: Bulk seed predefined canonical tags
Future<void> exampleBulkSeedTags(AppDatabase database) async {
  final seeder = TagSeeder(database);

  // Define famous football players and their aliases
  final footballTags = [
    TagDefinition(
      canonicalName: 'lionel-messi',
      displayName: 'Lionel Messi',
      entityType: 'PERSON',
      description: 'Argentine footballer',
      aliases: ['messi', 'leo messi', 'leo', 'messi10', 'm10'],
      confidence: 0.95,
    ),
    TagDefinition(
      canonicalName: 'cristiano-ronaldo',
      displayName: 'Cristiano Ronaldo',
      entityType: 'PERSON',
      description: 'Portuguese footballer',
      aliases: ['ronaldo', 'cr7', 'cr 7', 'cristiano'],
      confidence: 0.95,
    ),
    TagDefinition(
      canonicalName: 'real-madrid',
      displayName: 'Real Madrid',
      entityType: 'TEAM',
      aliases: ['real madrid', 'rm', 'los blancos', 'merengues'],
      confidence: 0.95,
    ),
  ];

  // Seed all tags at once
  final count = await seeder.seedCanonicalTags(footballTags);
  debugPrint('Seeded $count canonical tags');
}

/// Example 7: Using the tag alias service for lookups
Future<void> exampleTagAliasResolution(AppDatabase database) async {
  final aliasService = TagAliasService(database);

  // Initialize the cache (recommended on app startup)
  await aliasService.initializeCache();

  // Seed common aliases
  await aliasService.seedCommonAliases();

  // Resolve user input to canonical tag
  final resolution = await aliasService.resolveTag('messi');
  if (resolution != null) {
    debugPrint('Resolved "messi" to: ${resolution.tag.displayName}');
    debugPrint('Match type: ${resolution.matchType}');
    debugPrint('Confidence: ${resolution.confidence}');
  }

  // Try fuzzy matching
  final fuzzyResolution = await aliasService.resolveTag('lional messy');
  if (fuzzyResolution != null) {
    debugPrint('Fuzzy matched "lional messy" to: ${fuzzyResolution.tag.displayName}');
    debugPrint('Confidence: ${fuzzyResolution.confidence}');
  }

  // Get all aliases for a tag
  if (resolution != null) {
    final aliases = await aliasService.getTagAliases(resolution.tagId);
    debugPrint('Aliases for Messi: $aliases');
  }
}

/// Example 8: Complete integration workflow in batch processing
Future<void> exampleCompleteWorkflow(AppDatabase database) async {
  debugPrint('=== Phase 4: Tag Normalization & Entity Seeding ===\n');

  // Step 1: Initialize services
  debugPrint('Step 1: Initializing services...');
  final normalizer = TagNormalizer();
  final seeder = TagSeeder(database);
  final aliasService = TagAliasService(database);

  // Step 2: Initialize alias cache for fast lookups
  debugPrint('Step 2: Initializing alias cache...');
  await aliasService.initializeCache();
  await aliasService.seedCommonAliases();

  // Step 3: Simulate API response with tags
  debugPrint('Step 3: Processing API response...');
  final apiResponse = [
    {
      'id': 'image_001',
      'title': 'Messi at World Cup',
      'tags': ['messi', 'lionel messi', 'football', 'argentina', 'world cup'],
    },
    {
      'id': 'image_002',
      'title': 'Ferrari F1 Car',
      'tags': ['formula 1', 'f1', 'ferrari', 'racing', 'motorsport'],
    },
  ];

  // Step 4: Process each image
  for (final image in apiResponse) {
    debugPrint('Processing image: ${image['title']}');

    final wallpaper = Wallpaper(
      id: 'openverse_${image['id']}',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      fullUrl: 'https://example.com/full.jpg',
      author: 'API Provider',
      category: 'general',
      aspectRatio: 1.78,
      source: 'openverse',
      sourceId: image['id'] as String,
      tags: (image['tags'] as List).cast<String>(),
    );

    // Step 5: Seed tags
    final success = await seeder.seedTagsFromImage(wallpaper);
    debugPrint('  → Seeded: $success');
  }

  debugPrint('✅ Tag normalization workflow complete!');
  debugPrint('');
  debugPrint('Result:');
  debugPrint('- All tags normalized and deduplicated');
  debugPrint('- Entity types detected (PERSON, TEAM, SPORT, etc.)');
  debugPrint('- Aliases created for fuzzy matching');
  debugPrint('- Images linked to tags with confidence scores');
  debugPrint('- Database ready for advanced tag-based search');
}

/// Example 9: Configuration for ClassificationStage with database
/// This should be used when initializing the batch processing pipeline
void examplePipelineConfiguration() {
  // When setting up the batch processing pipeline:
  // 1. Pass the AppDatabase to ClassificationStage
  // 2. Tags will automatically be seeded during classification
  // 3. No additional configuration needed

  // In your batch processor initialization:
  // final pipeline = BatchPipeline([
  //   FetchStage(),
  //   DownloadStage(),
  //   DedupStage(),
  //   NSFWStage(),
  //   QualityStage(),
  //   ClassificationStage(appDatabase: database), // Pass database here
  //   ResolutionVariantStage(),
  //   SearchIndexStage(),
  //   StorageStage(),
  // ]);
}

/// Example 10: Statistics and monitoring
Future<void> exampleStatisticsAndMonitoring(AppDatabase database) async {
  final aliasService = TagAliasService(database);

  // Check cache size
  await aliasService.initializeCache();

  // Get tag statistics
  // final stats = await aliasService.getStatistics();
  // debugPrint('Total tags: ${stats.totalTags}');
  // debugPrint('Total aliases: ${stats.totalAliases}');
  // debugPrint('Cache size: ${stats.cacheSize}');

  // Get popular tags
  // final popularTags = await aliasService.getPopularTags(limit: 20);
  // for (final tag in popularTags) {
  //   debugPrint('${tag.displayName}: ${tag.usageCount} images');
  // }
}

/// Main integration points in the codebase:
///
/// 1. **ClassificationStage** (pipeline/classification_stage.dart)
///    - Automatically seeds tags when processing candidates
///    - Detects entity types based on context
///    - Creates aliases for fuzzy matching
///
/// 2. **Batch Processing Pipeline** (batch_processor.dart)
///    - Integrates tag seeding into the processing flow
///    - Tags are seeded before images are stored
///    - Confidence scores track tag quality
///
/// 3. **API Providers** (services/providers/*.dart)
///    - OpenVerse, Unsplash, GIPHY, Pixabay
///    - Extract tags from API responses
///    - Pass tags to wallpaper metadata
///
/// 4. **Search Engine** (services/search/search_engine.dart)
///    - Uses tag aliases for fuzzy search
///    - Resolves user queries to canonical tags
///    - Returns results for all query variations
///
/// 5. **Database** (database/daos/*.dart)
///    - TagDAO: Manages canonical tags
///    - TagAliasDAO: Manages aliases
///    - ImageTagDAO: Links images to tags
///    - TagRelationDAO: Manages tag hierarchies

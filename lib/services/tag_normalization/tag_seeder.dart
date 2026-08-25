import 'package:flutter/foundation.dart';

import '../../database/daos/daos.dart';
import '../../database/app_database.dart';
import '../../models/wallpaper.dart';
import 'tag_normalizer.dart';

/// Service for seeding tags from wallpaper metadata into the v6 tag system
/// Handles tag normalization, deduplication, alias mapping, and entity type detection
class TagSeeder {
  final AppDatabase _appDatabase;
  late TagDAO _tagDAO;
  late ImageTagDAO _imageTagDAO;
  late TagAliasDAO _aliasDAO;
  late TagNormalizer _normalizer;

  TagSeeder(this._appDatabase) {
    _tagDAO = TagDAO(_appDatabase);
    _imageTagDAO = ImageTagDAO(_appDatabase);
    _aliasDAO = TagAliasDAO(_appDatabase);
    _normalizer = TagNormalizer();
  }

  /// Seeds tags from a single wallpaper into the database
  /// Extracts tags, normalizes them, detects entity types, and links to image
  /// Returns true if seeding was successful
  Future<bool> seedTagsFromImage(
    Wallpaper wallpaper, {
    bool updateExisting = false,
  }) async {
    try {
      if (wallpaper.tags == null || wallpaper.tags!.isEmpty) {
        return true; // No tags to seed, not an error
      }

      // Step 1: Extract and normalize tags
      final normalizedTags = _normalizer.extractTags(wallpaper.tags);
      if (normalizedTags.isEmpty) {
        return true;
      }

      // Step 2: Process each tag
      final tagsToLink = <int>[];

      for (final normalizedTag in normalizedTags) {
        // Get or create canonical tag
        var tag = await _tagDAO.getByCanonicalName(normalizedTag);

        if (tag == null) {
          // Create new tag with detected entity type
          final entityType = _detectEntityType(normalizedTag, wallpaper);
          final displayName = _buildDisplayName(normalizedTag);

          final newTag = Tag(
            id: 0,
            canonicalName: normalizedTag,
            displayName: displayName,
            tagType: entityType,
            confidence: _getConfidenceScore(wallpaper.source ?? 'unknown'),
            createdAt: DateTime.now(),
          );

          final tagId = await _tagDAO.insert(newTag);
          tagsToLink.add(tagId);

          // If we have the original tag from API, add it as an alias
          final originalTag = wallpaper.tags!.firstWhere(
            (t) => _normalizer.normalizeText(t) == normalizedTag,
            orElse: () => '',
          );

          if (originalTag.isNotEmpty && originalTag != displayName) {
            await _addAlias(
              tagId,
              originalTag,
              source: wallpaper.source ?? 'api_metadata',
            );
          }
        } else {
          tagsToLink.add(tag.id);

          // Update tag if needed (confidence, etc)
          if (updateExisting) {
            final newConfidence = _getConfidenceScore(wallpaper.source ?? 'unknown');
            if (newConfidence > tag.confidence) {
              await _tagDAO.update(tag.copyWith(confidence: newConfidence));
            }
          }
        }
      }

      // Step 3: Link image to tags with confidence scores
      final imageTagsToInsert = <ImageTag>[];
      for (final tagId in tagsToLink) {
        imageTagsToInsert.add(ImageTag(
          id: 0,
          wallpaperId: wallpaper.id,
          tagId: tagId,
          confidence: 1.0, // API-provided tags have maximum confidence
          source: wallpaper.source ?? 'api_metadata',
          createdAt: DateTime.now(),
        ));
      }

      if (imageTagsToInsert.isNotEmpty) {
        await _imageTagDAO.insertBatch(imageTagsToInsert);
      }

      debugPrint(
        'TagSeeder: Seeded ${normalizedTags.length} tags for image ${wallpaper.id}',
      );
      return true;
    } catch (e) {
      debugPrint('TagSeeder error seeding image ${wallpaper.id}: $e');
      return false;
    }
  }

  /// Seeds canonical tags in bulk from a list of tag definitions
  /// Useful for pre-populating known entities (teams, players, etc.)
  Future<int> seedCanonicalTags(
    List<TagDefinition> tags, {
    String source = 'manual_seeding',
  }) async {
    try {
      final tagObjects = <Tag>[];

      for (final tagDef in tags) {
        final existing = await _tagDAO.getByCanonicalName(tagDef.canonicalName);
        if (existing == null) {
          tagObjects.add(Tag(
            id: 0,
            canonicalName: tagDef.canonicalName,
            displayName: tagDef.displayName,
            tagType: tagDef.entityType,
            description: tagDef.description,
            confidence: tagDef.confidence,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (tagObjects.isNotEmpty) {
        await _tagDAO.insertBatch(tagObjects);
      }

      // Add aliases for each tag definition
      for (final tagDef in tags) {
        final tag = await _tagDAO.getByCanonicalName(tagDef.canonicalName);
        if (tag != null && tagDef.aliases.isNotEmpty) {
          for (final alias in tagDef.aliases) {
            await _addAlias(tag.id, alias, source: source);
          }
        }
      }

      debugPrint('TagSeeder: Seeded ${tagObjects.length} canonical tags');
      return tagObjects.length;
    } catch (e) {
      debugPrint('TagSeeder error in seedCanonicalTags: $e');
      return 0;
    }
  }

  /// Detects entity type from a tag and context
  /// Returns one of: PERSON, TEAM, SPORT, COMPETITION, LOCATION, THEME, STYLE, etc.
  String _detectEntityType(String normalizedTag, Wallpaper wallpaper) {
    // Check if tag looks like a person
    if (_normalizer.personNameLikelihood(normalizedTag) > 0.6) {
      return 'PERSON';
    }

    // Check if tag looks like a location
    if (_normalizer.isLikelyLocation(normalizedTag)) {
      return 'LOCATION';
    }

    // Check if tag looks like sports-related
    if (_normalizer.isLikelySports(normalizedTag)) {
      // Further differentiate between TEAM, SPORT, COMPETITION
      final norm = normalizedTag.toLowerCase();
      if (norm.contains('team') || norm.contains('fc') || norm.contains('united')) {
        return 'TEAM';
      }
      if (norm.contains('league') ||
          norm.contains('cup') ||
          norm.contains('championship') ||
          norm.contains('tournament')) {
        return 'COMPETITION';
      }
      return 'SPORT';
    }

    // Check wallpaper's primary category for context
    if (wallpaper.primaryCategory?.toLowerCase().contains('deportes') ?? false) {
      return 'SPORT';
    }

    // Default to generic CONCEPT or TAG
    if (wallpaper.tags != null && wallpaper.tags!.length > 3) {
      return 'TAG'; // Generic tag from API
    }

    return 'CONCEPT';
  }

  /// Gets confidence score based on source
  /// API-provided: 1.0 (highest)
  /// Inferred from visual analysis: 0.8
  /// Fuzzy matched: 0.5
  double _getConfidenceScore(String source) {
    return switch (source) {
      'openverse' || 'unsplash' || 'giphy' || 'pixabay' || 'wallhaven' => 1.0,
      'visual_analysis' => 0.8,
      'fuzzy_match' => 0.5,
      'manual_seeding' => 0.95,
      'api_metadata' => 1.0,
      _ => 0.7,
    };
  }

  /// Builds a display name from a canonical name
  /// Example: "lionel-messi" → "Lionel Messi"
  String _buildDisplayName(String canonicalName) {
    return canonicalName
        .replaceAll(RegExp(r'[\-_]'), ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  /// Adds an alias for a tag
  Future<void> _addAlias(
    int tagId,
    String aliasText, {
    String source = 'api_metadata',
    double confidence = 1.0,
  }) async {
    try {
      final normalizedAlias = _normalizer.normalizeText(aliasText);
      if (normalizedAlias.isEmpty) return;

      // Check if alias already exists
      final existing = await _aliasDAO.getByNormalizedAlias(normalizedAlias);
      if (existing.isNotEmpty) {
        return; // Alias already exists
      }

      final alias = TagAlias(
        id: 0,
        tagId: tagId,
        aliasText: aliasText,
        normalizedAlias: normalizedAlias,
        source: source,
        confidence: confidence,
        createdAt: DateTime.now(),
      );

      await _aliasDAO.insert(alias);
    } catch (e) {
      debugPrint('TagSeeder error adding alias: $e');
    }
  }

}

/// Definition for bulk seeding of canonical tags
class TagDefinition {
  final String canonicalName; // 'lionel-messi'
  final String displayName; // 'Lionel Messi'
  final String entityType; // 'PERSON', 'TEAM', etc.
  final String? description;
  final List<String> aliases; // ['messi', 'leo', 'm10']
  final double confidence;

  TagDefinition({
    required this.canonicalName,
    required this.displayName,
    required this.entityType,
    this.description,
    this.aliases = const [],
    this.confidence = 0.95,
  });
}

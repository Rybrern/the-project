import 'package:flutter/foundation.dart';

import '../../database/daos/daos.dart';
import '../../database/app_database.dart';
import 'tag_normalizer.dart';

/// Service for managing tag aliases and fuzzy matching
/// Resolves user input (search queries, imported tags) to canonical tags
class TagAliasService {
  final AppDatabase _appDatabase;
  late TagDAO _tagDAO;
  late TagAliasDAO _aliasDAO;
  late TagNormalizer _normalizer;

  // Cache for frequently used aliases
  late Map<String, int?> _aliasCache;
  bool _cacheInitialized = false;

  TagAliasService(this._appDatabase) {
    _tagDAO = TagDAO(_appDatabase);
    _aliasDAO = TagAliasDAO(_appDatabase);
    _normalizer = TagNormalizer();
    _aliasCache = {};
  }

  /// Initialize the cache (should be called once on app startup)
  Future<void> initializeCache() async {
    if (_cacheInitialized) return;

    try {
      // Get all tags and their aliases to build cache
      final allTags = await _tagDAO.getAll(limit: 50000);
      int totalAliases = 0;

      for (final tag in allTags) {
        final aliases = await _aliasDAO.getByTagId(tag.id);
        for (final alias in aliases) {
          _aliasCache[alias.normalizedAlias] = alias.tagId;
          totalAliases++;
        }
        // Also add the canonical name as an alias
        _aliasCache[tag.canonicalName] = tag.id;
      }

      _cacheInitialized = true;
      debugPrint('TagAliasService: Initialized cache with $totalAliases aliases for ${allTags.length} tags');
    } catch (e) {
      debugPrint('TagAliasService: Error initializing cache: $e');
    }
  }

  /// Resolves a user input string to a canonical tag
  /// Tries exact match first, then fuzzy match
  /// Returns TagResolution with tag info and confidence
  Future<TagResolution?> resolveTag(String input) async {
    if (input.isEmpty) return null;

    final normalized = _normalizer.normalizeText(input);
    if (normalized.isEmpty) return null;

    // Step 1: Check cache for exact normalized match
    if (_cacheInitialized && _aliasCache.containsKey(normalized)) {
      final tagId = _aliasCache[normalized];
      if (tagId != null) {
        final tag = await _tagDAO.getById(tagId);
        if (tag != null) {
          return TagResolution(
            tagId: tag.id,
            tag: tag,
            matchType: 'exact_alias',
            confidence: 1.0,
            matchedInput: input,
          );
        }
      }
    }

    // Step 2: Try direct database lookup for exact match
    var tagId = await _aliasDAO.resolveAlias(normalized);
    if (tagId != null) {
      final tag = await _tagDAO.getById(tagId);
      if (tag != null) {
        _aliasCache[normalized] = tagId; // Update cache
        return TagResolution(
          tagId: tag.id,
          tag: tag,
          matchType: 'exact_alias',
          confidence: 1.0,
          matchedInput: input,
        );
      }
    }

    // Step 3: Try matching against canonical names
    final tag = await _tagDAO.getByCanonicalName(normalized);
    if (tag != null) {
      return TagResolution(
        tagId: tag.id,
        tag: tag,
        matchType: 'canonical_name',
        confidence: 1.0,
        matchedInput: input,
      );
    }

    // Step 4: Fuzzy match against all tags
    return _fuzzyMatchTag(input);
  }

  /// Fuzzy matches input against all tags using Levenshtein distance
  /// Returns best match if confidence > 0.7, otherwise null
  Future<TagResolution?> _fuzzyMatchTag(String input) async {
    try {
      final allTags = await _tagDAO.getAll(limit: 10000);
      if (allTags.isEmpty) return null;

      TagResolution? bestMatch;
      double bestScore = 0.7; // Minimum confidence threshold

      for (final tag in allTags) {
        final score1 =
            _normalizer.fuzzyMatchScore(input, tag.canonicalName);
        final score2 =
            _normalizer.fuzzyMatchScore(input, tag.displayName);

        final score = [score1, score2].reduce((a, b) => a > b ? a : b);

        if (score > bestScore) {
          bestScore = score;
          bestMatch = TagResolution(
            tagId: tag.id,
            tag: tag,
            matchType: 'fuzzy_match',
            confidence: score,
            matchedInput: input,
          );
        }
      }

      return bestMatch;
    } catch (e) {
      debugPrint('TagAliasService: Error in fuzzy matching: $e');
      return null;
    }
  }

  /// Adds a new alias for an existing tag
  Future<bool> addAlias(
    int tagId,
    String aliasText, {
    String source = 'user_input',
    double confidence = 0.9,
  }) async {
    try {
      final normalizedAlias = _normalizer.normalizeText(aliasText);
      if (normalizedAlias.isEmpty) {
        return false;
      }

      // Check if alias already exists
      final existing = await _aliasDAO.getByNormalizedAlias(normalizedAlias);
      if (existing.isNotEmpty) {
        return false; // Alias already exists
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

      // Update cache
      if (_cacheInitialized) {
        _aliasCache[normalizedAlias] = tagId;
      }

      return true;
    } catch (e) {
      debugPrint('TagAliasService: Error adding alias: $e');
      return false;
    }
  }

  /// Seeds pre-defined common aliases
  /// Should be called during app initialization
  Future<void> seedCommonAliases() async {
    try {
      final commonAliases = _getCommonAliasDefinitions();
      int aliasCount = 0;

      for (final definition in commonAliases) {
        final tag = await _tagDAO.getByCanonicalName(definition.canonicalName);
        if (tag != null) {
          for (final alias in definition.aliases) {
            final added = await addAlias(
              tag.id,
              alias,
              source: 'common_aliases',
              confidence: 0.95,
            );
            if (added) aliasCount++;
          }
        }
      }

      debugPrint('TagAliasService: Seeded $aliasCount common aliases');
    } catch (e) {
      debugPrint('TagAliasService: Error seeding common aliases: $e');
    }
  }

  /// Returns list of pre-defined common aliases
  List<_AliasDefinition> _getCommonAliasDefinitions() {
    return [
      // Sports figures
      _AliasDefinition(
        'lionel-messi',
        ['messi', 'leo messi', 'lionel andres messi', 'messi10', 'm10', 'leo'],
      ),
      _AliasDefinition(
        'cristiano-ronaldo',
        ['ronaldo', 'cr7', 'cristiano', 'cristiano ronaldo', 'cr 7'],
      ),
      _AliasDefinition(
        'neymar-jr',
        ['neymar', 'neymar junior', 'ney'],
      ),
      _AliasDefinition(
        'lewis-hamilton',
        ['hamilton', 'lewis hamilton', 'lh44', 'lh 44'],
      ),

      // Teams
      _AliasDefinition(
        'real-madrid',
        ['real madrid', 'rm', 'madrid', 'los blancos', 'merengues'],
      ),
      _AliasDefinition(
        'barcelona',
        ['barca', 'barcelona fc', 'fcb', 'fc barcelona'],
      ),
      _AliasDefinition(
        'manchester-city',
        ['man city', 'manchester city', 'city', 'mcfc'],
      ),
      _AliasDefinition(
        'manchester-united',
        ['man united', 'manchester united', 'united', 'mufc'],
      ),
      _AliasDefinition(
        'liverpool',
        ['lfc', 'liverpool fc'],
      ),
      _AliasDefinition(
        'psg',
        ['paris saint germain', 'paris sg', 'paris saint-germain'],
      ),
      _AliasDefinition(
        'bayern-munich',
        ['bayern', 'munich', 'fcb'],
      ),
      _AliasDefinition(
        'juventus',
        ['juve', 'juventus fc'],
      ),
      _AliasDefinition(
        'ferrari',
        ['ferrari team', 'scuderia ferrari', 'cavallino'],
      ),
      _AliasDefinition(
        'red-bull',
        ['red bull racing', 'rbr', 'red-bull-racing'],
      ),
      _AliasDefinition(
        'mercedes',
        ['mercedes amg', 'mercedes-amg'],
      ),
      _AliasDefinition(
        'mclaren',
        ['mcl', 'mclaren racing'],
      ),

      // Competitions
      _AliasDefinition(
        'formula-1',
        ['f1', 'formula one', 'f-1', 'formula 1'],
      ),
      _AliasDefinition(
        'champions-league',
        ['champs league', 'ucl', 'champions', 'champions league', 'cl'],
      ),
      _AliasDefinition(
        'premier-league',
        ['pl', 'epl', 'english premier league', 'premier league'],
      ),
      _AliasDefinition(
        'motogp',
        ['moto gp', 'moto-gp', 'motorcycle racing', 'motogp racing'],
      ),
      _AliasDefinition(
        'nba',
        ['nba basketball', 'national basketball association'],
      ),
      _AliasDefinition(
        'nfl',
        ['nfl football', 'national football league'],
      ),

      // Countries
      _AliasDefinition(
        'argentina',
        ['argentina football', 'seleccion argentina'],
      ),
      _AliasDefinition(
        'spain',
        ['spain football', 'spanish team'],
      ),
      _AliasDefinition(
        'england',
        ['england football', 'three lions'],
      ),
      _AliasDefinition(
        'brazil',
        ['brazil football', 'selecao'],
      ),
      _AliasDefinition(
        'france',
        ['france football', 'les bleus'],
      ),
      _AliasDefinition(
        'germany',
        ['germany football', 'die mannschaft'],
      ),

      // Styles & Themes
      _AliasDefinition(
        'cyberpunk',
        ['cyber punk', 'cybernetic', 'cyber'],
      ),
      _AliasDefinition(
        'sci-fi',
        ['science fiction', 'scifi', 'sf', 'sci fi'],
      ),
      _AliasDefinition(
        'fantasy',
        ['fantasy world', 'fantasy art'],
      ),
      _AliasDefinition(
        'abstract',
        ['abstract art', 'abstraction'],
      ),
      _AliasDefinition(
        'minimalist',
        ['minimal', 'minimalism', 'minimal art'],
      ),
      _AliasDefinition(
        'digital-art',
        ['digital', 'digital artwork', 'digital art'],
      ),
      _AliasDefinition(
        'neon',
        ['neon lights', 'neon glow'],
      ),
    ];
  }

  /// Gets all aliases for a tag
  Future<List<String>> getTagAliases(int tagId) async {
    try {
      final aliases = await _aliasDAO.getByTagId(tagId);
      return aliases.map((a) => a.aliasText).toList();
    } catch (e) {
      debugPrint('TagAliasService: Error getting aliases: $e');
      return [];
    }
  }

  /// Clears the alias cache
  void clearCache() {
    _aliasCache.clear();
    _cacheInitialized = false;
  }
}

/// Result of tag resolution
class TagResolution {
  final int tagId;
  final Tag tag;
  final String matchType; // 'exact_alias', 'canonical_name', 'fuzzy_match'
  final double confidence; // 0.0 - 1.0
  final String matchedInput;

  TagResolution({
    required this.tagId,
    required this.tag,
    required this.matchType,
    required this.confidence,
    required this.matchedInput,
  });

  @override
  String toString() =>
      'TagResolution(tag: ${tag.displayName}, match: $matchType, confidence: $confidence)';
}

class _AliasDefinition {
  final String canonicalName;
  final List<String> aliases;

  _AliasDefinition(this.canonicalName, this.aliases);
}

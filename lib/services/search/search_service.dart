import 'package:shared_preferences/shared_preferences.dart';

import '../../database/daos/daos.dart';
import '../../models/wallpaper.dart';
import 'tag_relation_expander.dart';
import 'popularity_ranker.dart';
import 'fuzzy_matcher.dart';
import 'search_analytics.dart';

/// Advanced search service with normalization, fuzzy matching, ranking, and analytics
/// Phase 5: Enhanced search capabilities with ranking, fuzzy matching, and tag expansion
class SearchService {
  final SearchIndexDAO _searchIndexDAO;
  final WallpaperDAO _wallpaperDAO;
  final AnimatedWallpaperDAO _animatedWallpaperDAO;
  final TagDAO _tagDAO;
  final TagRelationDAO _tagRelationDAO;

  late TagRelationExpander _tagExpander;
  late SearchAnalytics _analytics;

  SearchService({
    required SearchIndexDAO searchIndexDAO,
    required WallpaperDAO wallpaperDAO,
    required AnimatedWallpaperDAO animatedWallpaperDAO,
    required TagDAO tagDAO,
    required TagRelationDAO tagRelationDAO,
  })  : _searchIndexDAO = searchIndexDAO,
        _wallpaperDAO = wallpaperDAO,
        _animatedWallpaperDAO = animatedWallpaperDAO,
        _tagDAO = tagDAO,
        _tagRelationDAO = tagRelationDAO {
    _tagExpander = TagRelationExpander(
      tagDAO: _tagDAO,
      tagRelationDAO: _tagRelationDAO,
    );
    _initializeAnalytics();
  }

  void _initializeAnalytics() {
    SharedPreferences.getInstance().then((prefs) {
      _analytics = SearchAnalytics(prefs: prefs);
    });
  }

  /// Palabras vacías en español que no aportan valor de búsqueda
  static const _stopWords = {
    'el', 'la', 'de', 'y', 'a', 'en', 'un', 'una', 'los', 'las',
    'del', 'al', 'con', 'por', 'para', 'se', 'su', 'es', 'son', 'está',
    'están', 'fue', 'fueron', 'sido', 'siendo', 'he', 'has', 'ha',
    'hemos', 'habéis', 'han', 'haya', 'hayas', 'hayamos', 'hayáis',
  };

  /// Normaliza texto: conversión a minúsculas, eliminación de acentos y caracteres especiales
  String normalizeText(String text) {
    // Convertir a minúsculas
    text = text.toLowerCase();

    // Eliminar acentos (usando mapa simple)
    const accentMap = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ñ': 'n', 'ü': 'u',
    };
    accentMap.forEach((accented, clean) {
      text = text.replaceAll(accented, clean);
    });

    // Eliminar caracteres especiales, mantener solo letras, números y espacios
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // Normalizar espacios en blanco
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Tokeniza un texto en palabras, eliminando palabras vacías
  List<String> _tokenize(String text) {
    final normalized = normalizeText(text);
    return normalized
        .split(' ')
        .where((token) => token.isNotEmpty && !_stopWords.contains(token))
        .toList();
  }

  /// Calcula relevancia basada en tipo de entidad y coincidencias exactas
  double _calculateRelevance({
    required String entityType,
    required bool isExactMatch,
  }) {
    double relevance = 1.0;

    // Aumentar relevancia para tipos de entidad más específicos
    switch (entityType) {
      case 'player':
        relevance *= 1.5;
      case 'team':
        relevance *= 1.3;
      case 'tag':
        relevance *= 1.1;
      default:
        break;
    }

    // Duplicar relevancia para coincidencias exactas
    if (isExactMatch) {
      relevance *= 2.0;
    }

    return relevance;
  }

  /// Búsqueda exacta en índice (sin fuzzy matching)
  Future<List<Wallpaper>> searchExact(
    String query, {
    String? entityType,
    int limit = 50,
  }) async {
    final normalized = normalizeText(query);
    if (normalized.isEmpty) return [];

    // Buscar en índice
    final wallpaperIds = await _searchIndexDAO.search(
      normalized,
      entityType: entityType,
    );

    if (wallpaperIds.isEmpty) return [];

    // Obtener wallpapers completos
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIds.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }
    return wallpapers;
  }

  /// Búsqueda fuzzy (LIKE) en índice
  Future<List<Wallpaper>> searchFuzzy(
    String query, {
    String? entityType,
    int limit = 50,
  }) async {
    final normalized = normalizeText(query);
    if (normalized.isEmpty) return [];

    // Buscar en índice con fuzzy matching
    final wallpaperIds = await _searchIndexDAO.searchFuzzy(
      normalized,
      entityType: entityType,
    );

    if (wallpaperIds.isEmpty) return [];

    // Obtener wallpapers completos
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIds.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }
    return wallpapers;
  }

  /// Búsqueda por tokens individuales
  Future<List<Wallpaper>> searchByTokens(
    String query, {
    String? entityType,
    int limit = 50,
  }) async {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return [];

    // Buscar cada token
    final wallpaperIdSet = <String>{};
    for (final token in tokens) {
      final ids = await _searchIndexDAO.searchFuzzy(
        token,
        entityType: entityType,
      );
      wallpaperIdSet.addAll(ids);
    }

    if (wallpaperIdSet.isEmpty) return [];

    // Obtener wallpapers completos
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIdSet.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }
    return wallpapers;
  }

  /// Obtener sugerencias de autocompletado
  Future<List<String>> getAutocompleteSuggestions(
    String prefix, {
    int limit = 10,
  }) async {
    final normalized = normalizeText(prefix);
    if (normalized.isEmpty) return [];

    return await _searchIndexDAO.getAutocompleteSuggestions(
      normalized,
      limit: limit,
    );
  }

  /// Reconstruir índice de búsqueda a partir de wallpapers aceptados
  Future<void> rebuildSearchIndex() async {
    await _searchIndexDAO.rebuildIndex();

    // Obtener todos los wallpapers aceptados
    final allWallpapers = await _wallpaperDAO.getAllAccepted();

    // Construir entradas de índice
    final entries = <SearchIndexEntry>[];
    for (final wallpaper in allWallpapers) {
      // Indexar nombre/categoría
      if (wallpaper.category.isNotEmpty) {
        final normalized = normalizeText(wallpaper.category);
        entries.add(SearchIndexEntry(
          id: 0,
          wallpaperId: wallpaper.id,
          queryText: normalized,
          entityType: 'category',
          relevance: _calculateRelevance(
            entityType: 'category',
            isExactMatch: true,
          ),
          createdAt: DateTime.now(),
        ));
      }

      // Indexar tags individuales
      if (wallpaper.tags != null) {
        for (final tag in wallpaper.tags!) {
          final normalized = normalizeText(tag);
          entries.add(SearchIndexEntry(
            id: 0,
            wallpaperId: wallpaper.id,
            queryText: normalized,
            entityType: 'tag',
            relevance: _calculateRelevance(
              entityType: 'tag',
              isExactMatch: false,
            ),
            createdAt: DateTime.now(),
          ));
        }
      }

      // Indexar metadatos de entidades (nombres de jugadores, equipos, etc.)
      if (wallpaper.entityMetadata != null) {
        wallpaper.entityMetadata!.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            final normalized = normalizeText(value);
            entries.add(SearchIndexEntry(
              id: 0,
              wallpaperId: wallpaper.id,
              queryText: normalized,
              entityType: key, // 'player', 'team', etc.
              relevance: _calculateRelevance(
                entityType: key,
                isExactMatch: true,
              ),
              createdAt: DateTime.now(),
            ));
          }
        });
      }
    }

    // Insertar todas las entradas en batch
    if (entries.isNotEmpty) {
      await _searchIndexDAO.insertBatch(entries);
    }
  }

  // ============================================================================
  // PHASE 5: Advanced Search Features
  // ============================================================================

  /// Advanced search with tag expansion, ranking, and filtering
  /// Supports sources, date ranges, quality minimums, aspect ratios
  Future<List<Wallpaper>> searchWithFilters(
    String query, {
    List<String>? sourceFilter, // ['unsplash', 'giphy', 'openverse']
    DateRange? dateRange,
    double? qualityMinimum,
    String? aspectRatio, // 'portrait', 'landscape', 'square'
    int limit = 50,
  }) async {
    // Get base results with tag expansion
    final baseResults = await _searchWithExpansion(query, limit: limit * 2);
    var filtered = baseResults;

    // Apply source filter
    if (sourceFilter != null && sourceFilter.isNotEmpty) {
      filtered = filtered
          .where((w) => sourceFilter.contains(w.source?.toLowerCase()))
          .toList();
    }

    // Apply date range filter
    if (dateRange != null) {
      filtered = filtered.where((w) {
        if (w.processedAt == null) return false;
        return w.processedAt!.isAfter(dateRange.start) &&
            w.processedAt!.isBefore(dateRange.end);
      }).toList();
    }

    // Apply quality filter
    if (qualityMinimum != null) {
      filtered = filtered
          .where((w) => (w.qualityScore ?? 0.0) >= qualityMinimum)
          .toList();
    }

    // Apply aspect ratio filter
    if (aspectRatio != null) {
      filtered = filtered.where((w) => _matchesAspectRatio(w.aspectRatio, aspectRatio)).toList();
    }

    // Rank by popularity
    final ranked = PopularityRanker.rankByPopularity(
      filtered.take(limit).toList(),
      relevanceScores: _buildRelevanceScores(filtered),
    );

    // Record analytics
    await _recordSearch(query, ranked.length);

    return ranked;
  }

  /// Search with tag relation expansion
  /// Expands query tags to related tags (teams, competitions, etc.)
  Future<List<Wallpaper>> _searchWithExpansion(
    String query, {
    int limit = 50,
  }) async {
    // Tokenize query
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return [];

    // Expand each token using tag relations
    final expandedTags = <String>{};
    for (final token in tokens) {
      try {
        final expanded = await _tagExpander.expandTag(token, maxDepth: 2);
        expandedTags.addAll(expanded);
      } catch (_) {
        // If expansion fails, just use the original token
        expandedTags.add(token);
      }
    }

    // Search using expanded tags
    final wallpaperIds = <String>{};
    for (final tag in expandedTags) {
      final normalized = normalizeText(tag);
      if (normalized.isNotEmpty) {
        final ids = await _searchIndexDAO.searchFuzzy(normalized);
        wallpaperIds.addAll(ids);
      }
    }

    if (wallpaperIds.isEmpty) return [];

    // Fetch wallpapers
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIds.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }

    return wallpapers;
  }

  /// Enhanced autocomplete with top tags, locations, and trending
  Future<List<String>> getEnhancedAutocompleteSuggestions(
    String prefix, {
    int limit = 10,
  }) async {
    final normalized = normalizeText(prefix);
    if (normalized.isEmpty) return [];

    final suggestions = <String>{};

    // Get basic autocomplete
    final basic = await _searchIndexDAO.getAutocompleteSuggestions(
      normalized,
      limit: limit,
    );
    suggestions.addAll(basic);

    // Get top tags by frequency
    try {
      final topTags = await _getTopFrequentTags(limit: limit);
      suggestions.addAll(topTags);
    } catch (_) {
      // Silently fail if tag service unavailable
    }

    // Get recent searches from analytics
    try {
      if (_analytics != null) {
        final recentSearches = await _analytics!.getRecentSearches(limit: limit);
        for (final search in recentSearches) {
          final q = search['query'] as String?;
          if (q != null && q.toLowerCase().startsWith(normalized)) {
            suggestions.add(q);
          }
        }
      }
    } catch (_) {
      // Silently fail if analytics unavailable
    }

    return suggestions.take(limit).toList();
  }

  /// Search by photographer/author (Unsplash-specific)
  Future<List<Wallpaper>> searchByPhotographer(String photographerName) async {
    final normalized = normalizeText(photographerName);
    final wallpapers = await _wallpaperDAO.getBySource('unsplash');

    final filtered = wallpapers
        .where((w) => normalizeText(w.author).contains(normalized))
        .toList();

    // Rank by popularity
    final ranked = PopularityRanker.rankByPopularity(
      filtered,
      relevanceScores: _buildRelevanceScores(filtered),
    );

    await _recordSearch('photographer:$photographerName', ranked.length);
    return ranked;
  }

  /// Search by location (Unsplash metadata)
  Future<List<Wallpaper>> searchByLocation(String location) async {
    final normalized = normalizeText(location);
    final wallpapers = await _wallpaperDAO.getBySource('unsplash');

    final filtered = wallpapers.where((w) {
      if (w.entityMetadata == null) return false;
      final locValue = w.entityMetadata!['location']?.toString() ?? '';
      return normalizeText(locValue).contains(normalized);
    }).toList();

    // Rank by popularity
    final ranked = PopularityRanker.rankByPopularity(
      filtered,
      relevanceScores: _buildRelevanceScores(filtered),
    );

    await _recordSearch('location:$location', ranked.length);
    return ranked;
  }

  /// Get GIPHY trending content
  Future<List<Wallpaper>> getTrendingContent({int limit = 20}) async {
    final giphyWallpapers = await _wallpaperDAO.getBySource('giphy');

    // Sort by recency (trending = recent + popular)
    final sorted = giphyWallpapers.toList();
    sorted.sort((a, b) {
      final dateA = a.processedAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
      final dateB = b.processedAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    // Apply popularity ranking
    final ranked = PopularityRanker.rankByPopularity(
      sorted.take(limit).toList(),
      relevanceScores: _buildRelevanceScores(sorted),
    );

    await _recordSearch('trending', ranked.length);
    return ranked;
  }

  /// Gets top tags by search frequency (used for autocomplete)
  Future<List<String>> _getTopFrequentTags({int limit = 10}) async {
    try {
      final tags = await _tagDAO.getAll(limit: limit);
      return tags.map((t) => t.displayName).toList();
    } catch (_) {
      return [];
    }
  }

  /// Records a search in analytics
  Future<void> _recordSearch(String query, int resultCount) async {
    try {
      if (_analytics != null) {
        await _analytics!.recordSearch(
          query: query,
          resultCount: resultCount,
        );
      }
    } catch (_) {
      // Silently ignore analytics errors
    }
  }

  /// Builds a relevance score map for ranking
  Map<String, double> _buildRelevanceScores(List<Wallpaper> wallpapers) {
    final scores = <String, double>{};
    for (final wallpaper in wallpapers) {
      scores[wallpaper.id] = 0.5; // Default middle score
    }
    return scores;
  }

  /// Checks if aspect ratio matches filter
  bool _matchesAspectRatio(double aspectRatio, String filter) {
    switch (filter.toLowerCase()) {
      case 'portrait':
        return aspectRatio < 1.0;
      case 'landscape':
        return aspectRatio > 1.0;
      case 'square':
        return (aspectRatio - 1.0).abs() < 0.1;
      default:
        return true;
    }
  }
}

/// Date range for filtering
class DateRange {
  const DateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  /// Last week
  factory DateRange.lastWeek() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }

  /// Last month
  factory DateRange.lastMonth() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  /// All time
  factory DateRange.allTime() {
    return DateRange(
      start: DateTime(1970),
      end: DateTime.now(),
    );
  }
}

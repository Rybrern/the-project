import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';
import '../../models/wallpaper.dart';
import '../search/search_service.dart';

/// Métricas de validación de búsqueda
class SearchMetrics {
  final double precision; // TP / (TP + FP) - relevant results returned
  final double recall; // TP / (TP + FN) - all relevant results found
  final double fMeasure; // Harmonic mean of precision and recall
  final double avgResponseTimeMs;
  final double p50ResponseTimeMs;
  final double p95ResponseTimeMs;
  final double p99ResponseTimeMs;
  final bool fuzzyMatchingWorks; // "aurorr" → "aurora"
  final bool rankingAccurate; // Most popular first
  final int testQueriesRun;
  final DateTime testedAt;

  SearchMetrics({
    required this.precision,
    required this.recall,
    required this.fMeasure,
    required this.avgResponseTimeMs,
    required this.p50ResponseTimeMs,
    required this.p95ResponseTimeMs,
    required this.p99ResponseTimeMs,
    required this.fuzzyMatchingWorks,
    required this.rankingAccurate,
    required this.testQueriesRun,
    required this.testedAt,
  });

  bool isHealthy() {
    return precision > 0.85 && // 85%+ precision
        recall > 0.80 && // 80%+ recall
        avgResponseTimeMs < 500 && // Under 500ms
        fuzzyMatchingWorks &&
        rankingAccurate;
  }

  Map<String, dynamic> toJson() {
    return {
      'precision': precision,
      'recall': recall,
      'fMeasure': fMeasure,
      'avgResponseTimeMs': avgResponseTimeMs,
      'p50ResponseTimeMs': p50ResponseTimeMs,
      'p95ResponseTimeMs': p95ResponseTimeMs,
      'p99ResponseTimeMs': p99ResponseTimeMs,
      'fuzzyMatchingWorks': fuzzyMatchingWorks,
      'rankingAccurate': rankingAccurate,
      'testQueriesRun': testQueriesRun,
      'isHealthy': isHealthy(),
      'testedAt': testedAt.toIso8601String(),
    };
  }
}

/// Validador de búsqueda
class SearchValidator {
  final SearchService _searchService;
  final WallpaperDAO _wallpaperDAO;

  SearchValidator({
    required SearchService searchService,
    required WallpaperDAO wallpaperDAO,
  })  : _searchService = searchService,
        _wallpaperDAO = wallpaperDAO;

  /// Valida la calidad de búsqueda
  Future<SearchMetrics> validateSearch() async {
    debugPrint('SearchValidator: Starting search validation...');

    try {
      // Queries de prueba con expected results
      final testQueries = _getTestQueries();

      int totalRelevant = 0;
      int totalReturned = 0;
      int truePositives = 0;
      final responseTimes = <double>[];
      bool fuzzyWorks = false;
      bool rankingGood = false;

      for (final query in testQueries) {
        final startTime = DateTime.now().millisecondsSinceEpoch.toDouble();

        // Ejecutar búsqueda
        final results = await _searchService.searchFuzzy(query.query, limit: 50);

        final endTime = DateTime.now().millisecondsSinceEpoch.toDouble();
        final responseTime = endTime - startTime;
        responseTimes.add(responseTime);

        totalReturned += results.length;
        totalRelevant += query.expectedCount;

        // Contar resultados verdaderos (simple matching)
        truePositives += _countRelevantResults(results, query);

        // Verificar fuzzy matching
        if (query.testFuzzy &&
            results.any((w) => w.tags?.any((t) =>
                t.toLowerCase().contains(query.query.toLowerCase())) ??
                false)) {
          fuzzyWorks = true;
        }

        // Verificar ranking (first result should be most relevant)
        if (results.isNotEmpty && query.expectedMostRelevant != null) {
          if (results.first.id == query.expectedMostRelevant ||
              results.first.category
                  .toLowerCase()
                  .contains(query.query.toLowerCase())) {
            rankingGood = true;
          }
        }
      }

      // Calcular métricas
      final precision =
          totalReturned > 0 ? truePositives / totalReturned : 0.0;
      final recall = totalRelevant > 0 ? truePositives / totalRelevant : 0.0;
      final fMeasure = precision + recall > 0
          ? 2 * (precision * recall) / (precision + recall)
          : 0.0;

      responseTimes.sort();
      final avgResponseTime = responseTimes.isEmpty
          ? 0.0
          : responseTimes.reduce((a, b) => a + b) / responseTimes.length;
      final p50ResponseTime =
          responseTimes[responseTimes.length ~/ 2];
      final p95ResponseTime = responseTimes[(responseTimes.length * 0.95).toInt()];
      final p99ResponseTime = responseTimes[(responseTimes.length * 0.99).toInt()];

      debugPrint(
        'SearchValidator: Validation complete. Precision: ${precision.toStringAsFixed(2)}, Recall: ${recall.toStringAsFixed(2)}, Avg time: ${avgResponseTime.toStringAsFixed(2)}ms',
      );

      return SearchMetrics(
        precision: precision.clamp(0.0, 1.0),
        recall: recall.clamp(0.0, 1.0),
        fMeasure: fMeasure.clamp(0.0, 1.0),
        avgResponseTimeMs: avgResponseTime,
        p50ResponseTimeMs: p50ResponseTime,
        p95ResponseTimeMs: p95ResponseTime,
        p99ResponseTimeMs: p99ResponseTime,
        fuzzyMatchingWorks: fuzzyWorks,
        rankingAccurate: rankingGood,
        testQueriesRun: testQueries.length,
        testedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('SearchValidator: Error during validation: $e');
      rethrow;
    }
  }

  /// Valida búsqueda exacta
  Future<List<Wallpaper>> testExactSearch(String query) async {
    debugPrint('SearchValidator: Testing exact search for "$query"...');
    return await _searchService.searchExact(query, limit: 50);
  }

  /// Valida búsqueda fuzzy
  Future<List<Wallpaper>> testFuzzySearch(String query) async {
    debugPrint('SearchValidator: Testing fuzzy search for "$query"...');
    return await _searchService.searchFuzzy(query, limit: 50);
  }

  /// Valida búsqueda por tokens
  Future<List<Wallpaper>> testTokenSearch(String query) async {
    debugPrint('SearchValidator: Testing token search for "$query"...');
    return await _searchService.searchByTokens(query, limit: 50);
  }

  /// Obtiene sugerencias de autocompletado
  Future<List<String>> testAutoComplete(String prefix) async {
    debugPrint('SearchValidator: Testing autocomplete for "$prefix"...');
    return await _searchService.getAutocompleteSuggestions(prefix);
  }

  /// Cuenta resultados relevantes
  int _countRelevantResults(List<Wallpaper> results, TestQuery query) {
    int count = 0;
    for (final result in results) {
      // Si el resultado contiene el query term en tags o category, es relevante
      if (result.tags?.any((t) =>
              t.toLowerCase().contains(query.query.toLowerCase())) ??
          false) {
        count++;
      } else if (result.category
          .toLowerCase()
          .contains(query.query.toLowerCase())) {
        count++;
      }
    }
    return count;
  }

  /// Obtiene queries de prueba
  List<TestQuery> _getTestQueries() {
    return [
      TestQuery(
        query: 'messi',
        expectedCount: 50,
        expectedMostRelevant: null,
        testFuzzy: false,
        description: 'Should return Messi-related wallpapers',
      ),
      TestQuery(
        query: 'aurora',
        expectedCount: 30,
        expectedMostRelevant: null,
        testFuzzy: false,
        description: 'Should return Aurora content',
      ),
      TestQuery(
        query: 'aurorr',
        expectedCount: 30,
        expectedMostRelevant: null,
        testFuzzy: true,
        description: 'Typo - should match aurora (fuzzy matching)',
      ),
      TestQuery(
        query: 'football',
        expectedCount: 100,
        expectedMostRelevant: null,
        testFuzzy: false,
        description: 'Should return football-related content',
      ),
    ];
  }
}

/// Query de prueba
class TestQuery {
  final String query;
  final int expectedCount;
  final String? expectedMostRelevant;
  final bool testFuzzy;
  final String description;

  TestQuery({
    required this.query,
    required this.expectedCount,
    this.expectedMostRelevant,
    required this.testFuzzy,
    required this.description,
  });
}

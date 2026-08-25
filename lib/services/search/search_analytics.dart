import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Search Analytics - tracks user search behavior
/// Used to improve ranking over time and identify popular/failed searches
class SearchAnalytics {
  final SharedPreferences _prefs;

  static const String _recentSearchesKey = 'search_analytics_recent';
  static const String _searchStatsKey = 'search_analytics_stats';
  static const int _maxRecentSearches = 50;

  SearchAnalytics({required SharedPreferences prefs}) : _prefs = prefs;

  /// Records a search event
  Future<void> recordSearch({
    required String query,
    required int resultCount,
    int? selectedResultIndex,
    DateTime? timestamp,
  }) async {
    timestamp ??= DateTime.now();

    // Record in recent searches
    await _addRecentSearch(
      query: query,
      resultCount: resultCount,
      selectedResultIndex: selectedResultIndex,
      timestamp: timestamp,
    );

    // Update statistics
    await _updateSearchStats(query, resultCount);
  }

  /// Adds a search to the recent searches list
  Future<void> _addRecentSearch({
    required String query,
    required int resultCount,
    int? selectedResultIndex,
    required DateTime timestamp,
  }) async {
    final recentJson = _prefs.getStringList(_recentSearchesKey) ?? [];

    final searchEntry = {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      'result_count': resultCount,
      'selected_index': selectedResultIndex,
    };

    recentJson.add(jsonEncode(searchEntry));

    // Keep only the last N searches
    if (recentJson.length > _maxRecentSearches) {
      recentJson.removeRange(0, recentJson.length - _maxRecentSearches);
    }

    await _prefs.setStringList(_recentSearchesKey, recentJson);
  }

  /// Updates search statistics
  Future<void> _updateSearchStats(String query, int resultCount) async {
    final statsJson = _prefs.getString(_searchStatsKey) ?? '{}';
    final stats = jsonDecode(statsJson) as Map<String, dynamic>;

    final normalizedQuery = query.toLowerCase().trim();
    final queryStats = stats[normalizedQuery] as Map<String, dynamic>? ?? {
      'count': 0,
      'zero_results': 0,
      'total_results': 0,
      'first_search': DateTime.now().toIso8601String(),
      'last_search': DateTime.now().toIso8601String(),
    };

    queryStats['count'] = (queryStats['count'] as int? ?? 0) + 1;
    queryStats['total_results'] = (queryStats['total_results'] as int? ?? 0) + resultCount;
    if (resultCount == 0) {
      queryStats['zero_results'] = (queryStats['zero_results'] as int? ?? 0) + 1;
    }
    queryStats['last_search'] = DateTime.now().toIso8601String();

    stats[normalizedQuery] = queryStats;
    await _prefs.setString(_searchStatsKey, jsonEncode(stats));
  }

  /// Gets recent searches
  Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 10}) async {
    final recentJson = _prefs.getStringList(_recentSearchesKey) ?? [];
    final searches = <Map<String, dynamic>>[];

    // Reverse to get most recent first
    for (var i = recentJson.length - 1; i >= 0 && searches.length < limit; i--) {
      try {
        searches.add(jsonDecode(recentJson[i]) as Map<String, dynamic>);
      } catch (_) {
        // Skip malformed entries
      }
    }

    return searches;
  }

  /// Gets search statistics (top searches, zero-result searches, etc.)
  Future<Map<String, dynamic>> getSearchStatistics() async {
    final statsJson = _prefs.getString(_searchStatsKey) ?? '{}';
    final allStats = jsonDecode(statsJson) as Map<String, dynamic>;

    // Sort by search frequency
    final entries = allStats.entries.toList();
    entries.sort((a, b) {
      final countA = ((a.value as Map)['count'] as int?) ?? 0;
      final countB = ((b.value as Map)['count'] as int?) ?? 0;
      return countB.compareTo(countA);
    });

    final topSearches = Map.fromEntries(entries.take(10));

    // Find zero-result searches
    final zeroResults = <String, dynamic>{};
    for (final entry in entries) {
      final stats = entry.value as Map<String, dynamic>;
      if ((stats['zero_results'] as int? ?? 0) > 0) {
        zeroResults[entry.key] = stats;
      }
    }

    return {
      'total_searches': allStats.length,
      'top_searches': topSearches,
      'zero_result_searches': zeroResults,
      'average_results_per_search': _calculateAverageResults(allStats),
    };
  }

  /// Calculates average results per search
  static double _calculateAverageResults(Map<String, dynamic> stats) {
    if (stats.isEmpty) return 0.0;

    var totalResults = 0;
    var totalSearches = 0;

    for (final entry in stats.values) {
      if (entry is Map<String, dynamic>) {
        totalResults += (entry['total_results'] as int?) ?? 0;
        totalSearches += (entry['count'] as int?) ?? 0;
      }
    }

    return totalSearches > 0 ? totalResults / totalSearches : 0.0;
  }

  /// Gets top N searches by frequency
  Future<List<MapEntry<String, int>>> getTopSearches({int limit = 10}) async {
    final statsJson = _prefs.getString(_searchStatsKey) ?? '{}';
    final stats = jsonDecode(statsJson) as Map<String, dynamic>;

    final entries = <MapEntry<String, int>>[];
    for (final entry in stats.entries) {
      final count = ((entry.value as Map)['count'] as int?) ?? 0;
      entries.add(MapEntry(entry.key, count));
    }

    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).toList();
  }

  /// Gets searches that returned zero results
  Future<List<String>> getZeroResultSearches() async {
    final statsJson = _prefs.getString(_searchStatsKey) ?? '{}';
    final stats = jsonDecode(statsJson) as Map<String, dynamic>;

    final zeroResults = <String>[];
    for (final entry in stats.entries) {
      final zeroCount = ((entry.value as Map)['zero_results'] as int?) ?? 0;
      if (zeroCount > 0) {
        zeroResults.add(entry.key);
      }
    }

    return zeroResults;
  }

  /// Clears all analytics data
  Future<void> clearAnalytics() async {
    await _prefs.remove(_recentSearchesKey);
    await _prefs.remove(_searchStatsKey);
  }

  /// Clears recent searches only
  Future<void> clearRecentSearches() async {
    await _prefs.remove(_recentSearchesKey);
  }

  /// Removes a specific search from statistics
  Future<void> removeSearch(String query) async {
    final normalizedQuery = query.toLowerCase().trim();
    final statsJson = _prefs.getString(_searchStatsKey) ?? '{}';
    final stats = jsonDecode(statsJson) as Map<String, dynamic>;

    stats.remove(normalizedQuery);
    await _prefs.setString(_searchStatsKey, jsonEncode(stats));
  }

  /// Exports analytics data for debugging/analysis
  Future<Map<String, dynamic>> exportAnalytics() async {
    final recentSearches = await getRecentSearches(limit: 100);
    final statistics = await getSearchStatistics();
    final topSearches = await getTopSearches(limit: 20);

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'recent_searches': recentSearches,
      'statistics': statistics,
      'top_searches': topSearches,
    };
  }
}

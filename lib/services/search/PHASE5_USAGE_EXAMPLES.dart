/// Phase 5 Advanced Search - Usage Examples
///
/// This file demonstrates real-world usage patterns for Phase 5 features.
/// Copy and adapt these examples into your widgets/services.

import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';
import '../../models/wallpaper.dart';
import 'tag_relation_expander.dart';
import 'popularity_ranker.dart';
import 'fuzzy_matcher.dart';
import 'search_analytics.dart';
import 'search_service.dart';

/// Example 1: Basic Advanced Search with Filters
///
/// Use case: User searches "Messi" and wants:
/// - Only Unsplash photos
/// - From the last month
/// - High quality only
/// - Landscape orientation
Future<void> example1_advancedSearch(SearchService searchService) async {
  try {
    final results = await searchService.searchWithFilters(
      'messi',
      sourceFilter: ['unsplash'],
      dateRange: DateRange.lastMonth(),
      qualityMinimum: 0.8,
      aspectRatio: 'landscape',
      limit: 20,
    );

    debugPrint('Found ${results.length} high-quality Messi photos');
    for (final wallpaper in results.take(5)) {
      debugPrint('- ${wallpaper.author} (quality: ${wallpaper.qualityScore})');
    }
  } catch (e) {
    debugPrint('Search error: $e');
  }
}

/// Example 2: Smart Autocomplete
///
/// Use case: Show autocomplete suggestions as user types
/// Combines:
/// - Top tags by frequency
/// - Prefix matching suggestions
/// - Recent user searches
Future<void> example2_smartAutocomplete(SearchService searchService) async {
  try {
    final prefix = 'tes';
    final suggestions = await searchService.getEnhancedAutocompleteSuggestions(
      prefix,
      limit: 10,
    );

    debugPrint('Autocomplete suggestions for "$prefix":');
    for (var i = 0; i < suggestions.length; i++) {
      debugPrint('  ${i + 1}. ${suggestions[i]}');
    }
  } catch (e) {
    debugPrint('Autocomplete error: $e');
  }
}

/// Example 3: Fuzzy Matching for Typos
///
/// Use case: User types "formul1" instead of "formula-1"
/// The fuzzy matcher handles typos gracefully
Future<void> example3_fuzzyMatching() async {
  // Direct fuzzy matching
  final matches = [
    'formula-1',
    'formula1',
    'formulae',
    'formula-2',
    'test',
  ];

  final results = FuzzyMatcher.findMatches('formul1', matches);

  debugPrint('Fuzzy matches for "formul1":');
  for (final match in results) {
    final score = FuzzyMatcher.matchScore('formul1', match);
    debugPrint('  - $match (match score: ${(score * 100).toStringAsFixed(1)}%)');
  }

  // Practical: handle user input with typos
  final userInput = 'aurorr'; // User typo
  final isPossibleMatch = FuzzyMatcher.fuzzyMatch(userInput, 'aurora');
  debugPrint('Is "$userInput" a match for "aurora"? $isPossibleMatch');
}

/// Example 4: Tag Relation Expansion
///
/// Use case: When searching for "Messi", automatically include:
/// - Teams he played for (Barcelona, PSG, Inter Miami)
/// - Countries (Argentina)
/// - Competitions (Champions League, World Cup)
Future<void> example4_tagExpansion(TagRelationExpander expander) async {
  try {
    // Expand a tag through relations
    final expanded = await expander.expandTag('lionel-messi', maxDepth: 2);

    debugPrint('Tags related to Lionel Messi:');
    for (final tag in expanded.take(10)) {
      debugPrint('  - $tag');
    }

    // Get specific relation types
    final teams = await expander.getTagsByRelationType(
      'lionel-messi',
      'player_of_team',
    );
    debugPrint('\nTeams Messi played for: $teams');

    // Check if tags are related
    final isRelated = await expander.areTagsRelated('lionel-messi', 'fc-barcelona');
    debugPrint('\nAre Messi and Barcelona related? $isRelated');
  } catch (e) {
    debugPrint('Tag expansion error: $e');
  }
}

/// Example 5: Popularity Ranking
///
/// Use case: Rank search results by popularity while maintaining relevance
Future<void> example5_popularityRanking(List<Wallpaper> searchResults) async {
  try {
    // Build relevance scores (example: from search relevance)
    final relevanceScores = <String, double>{};
    for (var i = 0; i < searchResults.length; i++) {
      // Higher relevance for results earlier in list
      relevanceScores[searchResults[i].id] = 1.0 - (i * 0.01);
    }

    // Rank by popularity
    final ranked = PopularityRanker.rankByPopularity(
      searchResults,
      relevanceScores: relevanceScores,
    );

    debugPrint('Top 5 results after popularity ranking:');
    for (var i = 0; i < ranked.take(5).length; i++) {
      final wp = ranked[i];
      debugPrint(
        '${i + 1}. ${wp.author} (source: ${wp.source}, quality: ${wp.qualityScore})',
      );
    }

    // Analyze popularity distribution
    final analysis = PopularityRanker.analyzePopularity(
      ranked,
      relevanceScores: relevanceScores,
    );
    debugPrint('\nPopularity analysis:');
    debugPrint('  Total results: ${analysis['total']}');
    debugPrint('  Average quality: ${analysis['average_quality']}');
  } catch (e) {
    debugPrint('Ranking error: $e');
  }
}

/// Example 6: Search Analytics
///
/// Use case: Track what users search for to improve search
/// and identify common failures
Future<void> example6_searchAnalytics(SearchAnalytics analytics) async {
  try {
    // Record a search
    await analytics.recordSearch(
      query: 'messi',
      resultCount: 42,
      selectedResultIndex: 1, // User clicked 2nd result
    );

    // Get statistics
    final stats = await analytics.getSearchStatistics();
    debugPrint('Search statistics:');
    debugPrint('  Total searches: ${stats['total_searches']}');
    debugPrint('  Average results per search: '
        '${(stats['average_results_per_search'] as double).toStringAsFixed(1)}');

    // Find top searches
    final topSearches = await analytics.getTopSearches(limit: 5);
    debugPrint('\nTop searches:');
    for (final entry in topSearches) {
      debugPrint('  ${entry.key}: ${entry.value} times');
    }

    // Find problematic searches (zero results)
    final zeroResults = await analytics.getZeroResultSearches();
    debugPrint('\nSearches with zero results (${zeroResults.length}):');
    for (final query in zeroResults.take(5)) {
      debugPrint('  - $query');
    }

    // Export all analytics for analysis
    final export = await analytics.exportAnalytics();
    debugPrint('\nAnalytics exported at: ${export['exported_at']}');
  } catch (e) {
    debugPrint('Analytics error: $e');
  }
}

/// Example 7: Complex Search Workflow
///
/// Use case: Complete real-world search with:
/// 1. Typo tolerance
/// 2. Tag expansion
/// 3. Filtering
/// 4. Ranking
/// 5. Analytics tracking
Future<void> example7_complexWorkflow(
  SearchService searchService,
  TagRelationExpander expander,
) async {
  try {
    // User's search query (might have typo)
    final userQuery = 'formul1 racing'; // "formul1" is a typo for "formula-1"

    debugPrint('Processing user query: "$userQuery"');

    // Step 1: Apply fuzzy matching to handle typo
    final candidates = ['formula-1', 'formula1', 'f1-racing', 'racing'];
    final fuzzyMatches = FuzzyMatcher.hybridMatch(userQuery, candidates);
    debugPrint('Fuzzy matches found: ${fuzzyMatches.map((e) => e.key).toList()}');

    // Step 2: Expand tags (if we have tag relations)
    try {
      final expanded = await expander.expandTag('formula-1', maxDepth: 2);
      debugPrint('Expanded tags: ${expanded.take(5)}...');
    } catch (_) {
      debugPrint('Tag expansion unavailable, using base query');
    }

    // Step 3: Execute advanced search with filters
    final results = await searchService.searchWithFilters(
      userQuery,
      sourceFilter: ['unsplash', 'giphy'], // Any source
      dateRange: DateRange.lastMonth(), // Recent content
      qualityMinimum: 0.7, // Good quality
      aspectRatio: 'landscape', // Landscape format
      limit: 50,
    );

    debugPrint('Search returned ${results.length} results');

    // Step 4: Results are already ranked by popularity
    debugPrint('Top 3 results (by popularity):');
    for (var i = 0; i < results.take(3).length; i++) {
      final wp = results[i];
      debugPrint(
        '${i + 1}. ${wp.author} (${wp.source}, quality: ${wp.qualityScore})',
      );
    }

    debugPrint('✓ Search completed successfully');
  } catch (e) {
    debugPrint('Search error: $e');
  }
}

/// Example 8: Specialized Searches
///
/// Use case: Search by specific metadata fields
Future<void> example8_specializedSearches(SearchService searchService) async {
  try {
    // Search by photographer name
    debugPrint('1. Searching by photographer...');
    final byPhotographer = await searchService.searchByPhotographer('John Doe');
    debugPrint('   Found ${byPhotographer.length} photos by John Doe');

    // Search by location
    debugPrint('\n2. Searching by location...');
    final byLocation = await searchService.searchByLocation('Iceland');
    debugPrint('   Found ${byLocation.length} photos from Iceland');

    // Get trending content
    debugPrint('\n3. Getting trending content...');
    final trending = await searchService.getTrendingContent(limit: 10);
    debugPrint('   Found ${trending.length} trending items');
  } catch (e) {
    debugPrint('Specialized search error: $e');
  }
}

/// Example 9: Performance Monitoring
///
/// Use case: Monitor search performance and optimize
Future<void> example9_performanceMonitoring(SearchService searchService) async {
  try {
    final stopwatch = Stopwatch()..start();

    final results = await searchService.searchWithFilters(
      'nature landscape',
      sourceFilter: ['unsplash'],
      qualityMinimum: 0.7,
      limit: 20,
    );

    stopwatch.stop();

    debugPrint('Search performance metrics:');
    debugPrint('  Query: nature landscape');
    debugPrint('  Results: ${results.length}');
    debugPrint('  Time: ${stopwatch.elapsedMilliseconds}ms');
    debugPrint('  Time per result: '
        '${(stopwatch.elapsedMilliseconds / results.length).toStringAsFixed(2)}ms');

    // Flag if slow
    if (stopwatch.elapsedMilliseconds > 500) {
      debugPrint('  ⚠️  Warning: Search exceeded 500ms target!');
    } else {
      debugPrint('  ✓ Search performance is good');
    }
  } catch (e) {
    debugPrint('Performance monitoring error: $e');
  }
}

/// Example 10: Error Handling Best Practices
///
/// Use case: Graceful degradation when services fail
Future<void> example10_errorHandling(SearchService searchService) async {
  try {
    // Try advanced search first
    debugPrint('Attempting advanced search...');
    final results = await searchService.searchWithFilters(
      'nature',
      qualityMinimum: 0.8,
    ).timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {
        debugPrint('⚠️  Advanced search timed out, falling back to simple search');
        return [];
      },
    );

    if (results.isNotEmpty) {
      debugPrint('✓ Advanced search succeeded with ${results.length} results');
    } else {
      debugPrint('⚠️  Advanced search empty, trying simple search...');
      final simpleResults = await searchService.searchFuzzy('nature', limit: 50);
      debugPrint('✓ Simple search returned ${simpleResults.length} results');
    }
  } catch (e) {
    debugPrint('❌ Search failed: $e');
    // Fallback to cached results or show error message
  }
}

/// Example 11: Autocomplete with Real-time Suggestions
///
/// Use case: Stream autocomplete suggestions as user types (for UI)
///
/// In a real widget:
/// ```dart
/// StreamController<List<String>> suggestionStream = StreamController();
///
/// void onSearchInputChanged(String input) async {
///   if (input.length < 2) {
///     suggestionStream.add([]);
///     return;
///   }
///
///   final suggestions = await searchService.getEnhancedAutocompleteSuggestions(
///     input,
///     limit: 10,
///   );
///   suggestionStream.add(suggestions);
/// }
/// ```
Future<void> example11_autocompleteSuggestions(SearchService searchService) async {
  final inputs = ['m', 'me', 'mes', 'mess', 'messi'];

  for (final input in inputs) {
    try {
      final suggestions =
          await searchService.getEnhancedAutocompleteSuggestions(input, limit: 5);
      debugPrint('Suggestions for "$input": $suggestions');
    } catch (e) {
      debugPrint('Error getting suggestions for "$input": $e');
    }
  }
}

/// Example 12: Hybrid Matching for Fast Search
///
/// Use case: Use hybrid matching for instant suggestions (no DB)
Future<void> example12_hybridMatching() async {
  final tags = [
    'aurora',
    'australia',
    'austere',
    'austria',
    'aurora-borealis',
    'test',
    'testing',
  ];

  debugPrint('Hybrid matching for "aust":');
  final matches = FuzzyMatcher.hybridMatch('aust', tags);

  for (final match in matches) {
    debugPrint(
      '  ${match.key}: score ${(match.value * 100).toStringAsFixed(0)}%',
    );
  }
}

// ============================================================================
// UTILITY FUNCTIONS FOR WIDGETS
// ============================================================================

/// Helper to format search results for display
String formatWallpaperResult(Wallpaper wp) {
  return '${wp.author} - ${wp.category} '
      '(${(wp.qualityScore ?? 0.5 * 100).toStringAsFixed(0)}% quality)';
}

/// Helper to handle search with proper error handling
Future<List<Wallpaper>> safeSearch(
  SearchService searchService,
  String query,
) async {
  try {
    return await searchService.searchWithFilters(query, limit: 50);
  } catch (e) {
    debugPrint('Search error: $e');
    return [];
  }
}

/// Helper to show loading indicator during search
Future<List<Wallpaper>> searchWithProgress(
  SearchService searchService,
  String query,
  Function(bool) setLoading,
) async {
  try {
    setLoading(true);
    final results = await searchService.searchWithFilters(query, limit: 50);
    return results;
  } finally {
    setLoading(false);
  }
}

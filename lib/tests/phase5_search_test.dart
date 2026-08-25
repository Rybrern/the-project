import 'package:flutter_test/flutter_test.dart';
import '../services/search/fuzzy_matcher.dart';
import '../services/search/popularity_ranker.dart';
import '../models/wallpaper.dart';

void main() {
  group('Phase 5: Advanced Search Features', () {
    // ========================================================================
    // FuzzyMatcher Tests
    // ========================================================================
    group('FuzzyMatcher', () {
      test('calculates Levenshtein distance correctly', () {
        expect(FuzzyMatcher.levenshteinDistance('cat', 'cat'), 0);
        expect(FuzzyMatcher.levenshteinDistance('cat', 'car'), 1);
        expect(FuzzyMatcher.levenshteinDistance('kitten', 'sitting'), 3);
      });

      test('fuzzy matching with typo tolerance', () {
        expect(FuzzyMatcher.fuzzyMatch('aurorr', 'aurora'), true);
        expect(FuzzyMatcher.fuzzyMatch('formul1', 'formula1'), true);
        expect(FuzzyMatcher.fuzzyMatch('messi', 'messi'), true);
      });

      test('max distance calculation', () {
        expect(FuzzyMatcher.getMaxDistance('abc'), 1);
        expect(FuzzyMatcher.getMaxDistance('abcd'), 1);
        expect(FuzzyMatcher.getMaxDistance('abcdefghijk'), 3);
      });

      test('finds matches sorted by distance', () {
        final candidates = ['aurora', 'australia', 'austere', 'africa'];
        final matches = FuzzyMatcher.findMatches('aurorr', candidates);
        expect(matches.isNotEmpty, true);
        expect(matches.first, 'aurora'); // Best match
      });

      test('match score calculation', () {
        final score1 = FuzzyMatcher.matchScore('messi', 'messi');
        final score2 = FuzzyMatcher.matchScore('messi', 'mess');
        expect(score1, greaterThan(score2));
        expect(score1, 1.0);
      });

      test('prefix matching', () {
        expect(FuzzyMatcher.prefixMatch('tes', 'test'), true);
        expect(FuzzyMatcher.prefixMatch('test', 'tes'), false);
      });

      test('substring matching', () {
        expect(FuzzyMatcher.substringMatch('est', 'test'), true);
        expect(FuzzyMatcher.substringMatch('xyz', 'test'), false);
      });

      test('hybrid matching combines prefix and fuzzy', () {
        final candidates = ['aurora', 'australia', 'austere', 'test'];
        final matches = FuzzyMatcher.hybridMatch('aur', candidates);
        expect(matches.isNotEmpty, true);
        // Prefix matches should score higher than fuzzy
        final prefixMatches =
            matches.where((m) => m.key.startsWith('aur')).toList();
        expect(prefixMatches.isNotEmpty, true);
      });

      test('soundex matching for phonetic similarity', () {
        expect(FuzzyMatcher.soundexMatch('Smith', 'Smythe'), true);
        expect(FuzzyMatcher.soundexMatch('Robert', 'Rupert'), true);
      });

      test('optimized matching filters before fuzzy', () {
        final candidates = [
          'aurora',
          'australia',
          'austere',
          'test',
          'africa',
        ];
        final matches = FuzzyMatcher.optimizedMatch('aur', candidates);
        expect(matches.isNotEmpty, true);
        // Should only return candidates containing 'aur' plus fuzzy matches
        expect(
          matches.every(
            (m) => m.contains('aur') || FuzzyMatcher.fuzzyMatch('aur', m),
          ),
          true,
        );
      });
    });

    // ========================================================================
    // PopularityRanker Tests
    // ========================================================================
    group('PopularityRanker', () {
      test('calculates popularity score within bounds', () {
        final wallpaper = _createTestWallpaper(
          qualityScore: 0.8,
          source: 'unsplash',
        );
        final score = PopularityRanker.calculatePopularityScore(
          wallpaper,
          baseRelevanceScore: 0.5,
        );
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      });

      test('unsplash source gets boost', () {
        final unsplashScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(source: 'unsplash'),
          baseRelevanceScore: 0.5,
        );
        final genericScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(source: 'custom'),
          baseRelevanceScore: 0.5,
        );
        expect(unsplashScore, greaterThan(genericScore));
      });

      test('recent content gets recency boost', () {
        final recentTime = DateTime.now().subtract(const Duration(days: 1));
        final recentScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(processedAt: recentTime),
          baseRelevanceScore: 0.5,
        );
        final oldTime = DateTime.now().subtract(const Duration(days: 30));
        final oldScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(processedAt: oldTime),
          baseRelevanceScore: 0.5,
        );
        expect(recentScore, greaterThan(oldScore));
      });

      test('different sources affect ranking differently', () {
        final unsplashScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(source: 'unsplash', qualityScore: 0.5),
          baseRelevanceScore: 0.5,
        );
        final giphyScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(source: 'giphy', qualityScore: 0.5),
          baseRelevanceScore: 0.5,
        );
        final openverseScore = PopularityRanker.calculatePopularityScore(
          _createTestWallpaper(source: 'openverse', qualityScore: 0.5),
          baseRelevanceScore: 0.5,
        );

        // Unsplash should score highest
        expect(unsplashScore, greaterThan(giphyScore));
        expect(giphyScore, greaterThan(openverseScore));
      });

      test('view-based score calculation', () {
        final score1 = PopularityRanker.calculateViewBasedScore(0);
        final score2 = PopularityRanker.calculateViewBasedScore(50000);
        final score3 = PopularityRanker.calculateViewBasedScore(100000);

        expect(score1, 0.0);
        expect(score2, lessThan(1.0));
        expect(score3, 1.0);
      });

      test('engagement score calculation', () {
        final score = PopularityRanker.calculateEngagementScore(
          1000, // likes
          500, // downloads
        );
        expect(score, greaterThan(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      });

      test('ranks wallpapers by popularity', () {
        final wallpapers = [
          _createTestWallpaper(qualityScore: 0.5, source: 'pixabay'),
          _createTestWallpaper(qualityScore: 0.9, source: 'unsplash'),
          _createTestWallpaper(qualityScore: 0.7, source: 'giphy'),
        ];

        final ranked = PopularityRanker.rankByPopularity(
          wallpapers,
          relevanceScores: {
            wallpapers[0].id: 0.5,
            wallpapers[1].id: 0.5,
            wallpapers[2].id: 0.5,
          },
        );

        // Top-ranked should be the high-quality Unsplash one
        expect(ranked.first.qualityScore, greaterThanOrEqualTo(0.8));
      });

      test('tier-based scoring', () {
        final premiumWallpaper = _createTestWallpaper(
          qualityScore: 0.85,
          source: 'unsplash',
        );
        final standardWallpaper =
            _createTestWallpaper(qualityScore: 0.5, source: 'pixabay');

        final premiumScore = PopularityRanker.calculateTierScore(
          premiumWallpaper,
          baseScore: 0.5,
        );
        final standardScore = PopularityRanker.calculateTierScore(
          standardWallpaper,
          baseScore: 0.5,
        );

        expect(premiumScore, greaterThan(standardScore));
      });

      test('analyzes popularity distribution', () {
        final wallpapers = [
          _createTestWallpaper(source: 'unsplash', qualityScore: 0.8),
          _createTestWallpaper(source: 'unsplash', qualityScore: 0.7),
          _createTestWallpaper(source: 'giphy', qualityScore: 0.6),
        ];

        final analysis = PopularityRanker.analyzePopularity(
          wallpapers,
          relevanceScores: {
            wallpapers[0].id: 0.5,
            wallpapers[1].id: 0.5,
            wallpapers[2].id: 0.5,
          },
        );

        expect(analysis['total'], 3);
        expect(analysis['by_source'], isNotEmpty);
      });
    });

    // ========================================================================
    // Integration Tests
    // ========================================================================
    group('Integration Tests', () {
      test('fuzzy matching works with accents', () {
        expect(FuzzyMatcher.fuzzyMatch('aurora', 'aurórá'), true);
      });

      test('matching is case-insensitive', () {
        expect(FuzzyMatcher.fuzzyMatch('MESSI', 'messi'), true);
        expect(FuzzyMatcher.prefixMatch('TEST', 'test'), true);
      });

      test('popularity ranking respects quality threshold', () {
        final wallpapers = [
          _createTestWallpaper(qualityScore: 0.2),
          _createTestWallpaper(qualityScore: 0.8),
        ];

        final ranked = PopularityRanker.rankByPopularity(
          wallpapers,
          relevanceScores: {
            wallpapers[0].id: 0.5,
            wallpapers[1].id: 0.5,
          },
        );

        // Higher quality should rank first
        expect(ranked.first.qualityScore, greaterThan(0.5));
      });
    });
  });
}

// Helper function to create test wallpapers
Wallpaper _createTestWallpaper({
  String? source,
  double? qualityScore,
  DateTime? processedAt,
}) {
  return Wallpaper(
    id: 'test_${DateTime.now().millisecondsSinceEpoch}',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    fullUrl: 'https://example.com/full.jpg',
    author: 'Test Author',
    category: 'Test Category',
    aspectRatio: 1.0,
    source: source ?? 'unknown',
    qualityScore: qualityScore ?? 0.5,
    processedAt: processedAt,
  );
}

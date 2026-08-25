import '../../models/wallpaper.dart';

/// Popularity Ranker - scores wallpapers based on source, quality, recency
/// Used to rank search results by relevance + popularity
class PopularityRanker {
  /// Score wallpaper based on source, quality, and recency
  /// Returns a score from 0.0 to 1.0 representing popularity
  static double calculatePopularityScore(
    Wallpaper wallpaper, {
    required double baseRelevanceScore,
  }) {
    var score = baseRelevanceScore;

    // Quality score boost (0.0-1.0)
    if (wallpaper.qualityScore != null) {
      score = score * 0.7 + (wallpaper.qualityScore! * 0.3);
    }

    // Source-based scoring
    final sourceBoost = _getSourceBoost(wallpaper.source);
    score = score * (1.0 - sourceBoost) + sourceBoost;

    // Recency boost (last 7 days → +20%)
    final recencyBoost = _getRecencyBoost(wallpaper.processedAt);
    score = score * (1.0 + recencyBoost);

    // Clamp to [0.0, 1.0]
    return score.clamp(0.0, 1.0);
  }

  /// Gets a boost factor based on the source
  /// Unsplash and GIPHY are more popular sources
  static double _getSourceBoost(String? source) {
    switch (source?.toLowerCase()) {
      case 'unsplash':
        return 0.25; // +25% boost
      case 'giphy':
        return 0.20; // +20% boost
      case 'openverse':
        return 0.10; // +10% boost
      case 'pixabay':
        return 0.15; // +15% boost
      case 'wallhaven':
        return 0.12; // +12% boost
      default:
        return 0.0;
    }
  }

  /// Gets a boost for recently added content
  /// Content from last 7 days gets up to +20% boost
  static double _getRecencyBoost(DateTime? processedAt) {
    if (processedAt == null) return 0.0;

    final now = DateTime.now();
    final daysSince = now.difference(processedAt).inDays;

    if (daysSince <= 0) {
      return 0.20; // Fresh content
    } else if (daysSince <= 7) {
      // Gradual decrease from 20% to 0%
      return 0.20 * (1.0 - (daysSince / 7.0));
    }

    return 0.0;
  }

  /// Calculates view-based popularity (used if view counts available)
  /// Normalizes views to 0.0-1.0 range using linear scaling
  static double calculateViewBasedScore(int views, {int maxExpectedViews = 100000}) {
    if (views <= 0) return 0.0;

    // Linear scaling: views / maxExpectedViews
    final normalized = (views.toDouble() / maxExpectedViews).clamp(0.0, 1.0);

    return normalized;
  }

  /// Calculates engagement-based score from likes and downloads
  /// Used for Unsplash-like sources
  /// Score = (likes + downloads * 2) / max_engagement
  static double calculateEngagementScore(
    int likes,
    int downloads, {
    int maxExpectedEngagement = 10000,
  }) {
    final totalEngagement = likes + (downloads * 2); // Downloads weighted 2x
    return (totalEngagement.toDouble() / maxExpectedEngagement).clamp(0.0, 1.0);
  }

  /// Sorts wallpapers by popularity + relevance
  /// relevanceScores: map of wallpaper.id -> relevance (0.0-1.0)
  static List<Wallpaper> rankByPopularity(
    List<Wallpaper> wallpapers, {
    required Map<String, double> relevanceScores,
  }) {
    final scored = <MapEntry<Wallpaper, double>>[];

    for (final wallpaper in wallpapers) {
      final relevance = relevanceScores[wallpaper.id] ?? 0.5;
      final popularity = calculatePopularityScore(
        wallpaper,
        baseRelevanceScore: relevance,
      );
      scored.add(MapEntry(wallpaper, popularity));
    }

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.map((e) => e.key).toList();
  }

  /// Tier-based scoring for easier manual adjustment
  /// Returns a score based on wallpaper tier (premium, popular, standard)
  static double calculateTierScore(
    Wallpaper wallpaper, {
    required double baseScore,
  }) {
    var score = baseScore;

    // Premium tier: high quality + good source
    if ((wallpaper.qualityScore ?? 0.0) >= 0.8 &&
        ['unsplash', 'giphy'].contains(wallpaper.source?.toLowerCase())) {
      score *= 1.3;
    }
    // Popular tier: decent quality + any source
    else if ((wallpaper.qualityScore ?? 0.0) >= 0.6) {
      score *= 1.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Creates a popularity ranking report for debugging
  static Map<String, dynamic> analyzePopularity(
    List<Wallpaper> wallpapers, {
    required Map<String, double> relevanceScores,
  }) {
    if (wallpapers.isEmpty) {
      return {'total': 0, 'by_source': {}, 'average_quality': 0.0};
    }

    final bySource = <String, List<double>>{};

    for (final wallpaper in wallpapers) {
      final source = wallpaper.source ?? 'unknown';
      final score = calculatePopularityScore(
        wallpaper,
        baseRelevanceScore: relevanceScores[wallpaper.id] ?? 0.5,
      );

      bySource.putIfAbsent(source, () => []).add(score);
    }

    final avgQuality = wallpapers
            .map((w) => w.qualityScore ?? 0.5)
            .reduce((a, b) => a + b) /
        wallpapers.length;

    return {
      'total': wallpapers.length,
      'by_source': bySource.map(
        (source, scores) => MapEntry(
          source,
          {
            'count': scores.length,
            'average_score': scores.reduce((a, b) => a + b) / scores.length,
          },
        ),
      ),
      'average_quality': avgQuality,
    };
  }
}

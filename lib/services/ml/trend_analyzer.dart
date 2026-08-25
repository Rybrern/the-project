import 'package:flutter/foundation.dart';

/// Análisis de tendencias en wallpapers
class TrendAnalysisResult {
  const TrendAnalysisResult({
    required this.trendingCategories,
    required this.emergingCategories,
    required this.decliningCategories,
    required this.popularTags,
    required this.timestamp,
  });

  /// Categorías en tendencia (top 3)
  final List<TrendCategory> trendingCategories;

  /// Categorías emergentes (nuevas y crecientes)
  final List<TrendCategory> emergingCategories;

  /// Categorías en declive
  final List<TrendCategory> decliningCategories;

  /// Tags más populares
  final Map<String, int> popularTags;

  /// Timestamp del análisis
  final DateTime timestamp;
}

class TrendCategory {
  const TrendCategory({
    required this.name,
    required this.score,
    required this.growth,
    required this.volume,
  });

  /// Nombre de categoría
  final String name;

  /// Score de tendencia (0-1)
  final double score;

  /// Crecimiento porcentual
  final double growth;

  /// Volumen de items
  final int volume;
}

/// Analizador de tendencias
class TrendAnalyzer {
  final Map<String, int> _categoryHistory = {};
  final Map<String, int> _previousCategoryHistory = {};
  final Map<String, int> _tagFrequency = {};

  /// Registra una nueva categoría
  void recordCategory(String category) {
    _categoryHistory[category] = (_categoryHistory[category] ?? 0) + 1;
    debugPrint('TrendAnalyzer: Recorded category "$category"');
  }

  /// Registra tags
  void recordTags(List<String> tags) {
    for (final tag in tags) {
      _tagFrequency[tag] = (_tagFrequency[tag] ?? 0) + 1;
    }
  }

  /// Analiza tendencias actuales
  TrendAnalysisResult analyzeTrends() {
    // Calcular tendencias por categoría
    final trends = <String, TrendCategory>{};

    _categoryHistory.forEach((category, count) {
      final previousCount = _previousCategoryHistory[category] ?? 0;
      final growth = previousCount > 0
          ? ((count - previousCount) / previousCount * 100)
          : (count > 0 ? 100.0 : 0.0);

      final score = _calculateTrendScore(count, growth);

      trends[category] = TrendCategory(
        name: category,
        score: score,
        growth: growth,
        volume: count,
      );
    });

    // Ordenar por score
    final sortedTrends = trends.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Clasificar en trending, emerging, declining
    final trending = sortedTrends.take(3).toList();
    final emerging = sortedTrends
        .where((t) => t.growth > 25 && !trending.contains(t))
        .take(3)
        .toList();
    final declining = sortedTrends
        .where((t) => t.growth < -10)
        .take(3)
        .toList();

    // Top tags
    final topTags = <String, int>{};
    final sortedTags = _tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedTags.take(10)) {
      topTags[entry.key] = entry.value;
    }

    return TrendAnalysisResult(
      trendingCategories: trending,
      emergingCategories: emerging,
      decliningCategories: declining,
      popularTags: topTags,
      timestamp: DateTime.now(),
    );
  }

  /// Predice demanda futura
  Future<Map<String, double>> predictDemand({
    required int daysAhead,
  }) async {
    final predictions = <String, double>{};

    _categoryHistory.forEach((category, count) {
      // Modelo simple: asumir crecimiento lineal
      final avgDaily = count / 30.0; // Promedio diario (asumiendo 30 días)
      final projected = count + (avgDaily * daysAhead);
      predictions[category] = projected.clamp(0.0, 1.0);
    });

    return predictions;
  }

  /// Calcula score de tendencia
  double _calculateTrendScore(int count, double growth) {
    // Peso por volumen (60%) + crecimiento (40%)
    final volumeScore = (count / (_categoryHistory.values.reduce((a, b) => a + b) + 1)).clamp(0.0, 1.0);
    final growthScore = (growth / 100.0).clamp(0.0, 1.0);

    return (volumeScore * 0.6) + (growthScore * 0.4);
  }

  /// Actualiza histórico para comparación
  void updateHistory() {
    _previousCategoryHistory.clear();
    _previousCategoryHistory.addAll(_categoryHistory);
    _categoryHistory.clear();
    debugPrint('TrendAnalyzer: History updated');
  }

  /// Obtiene resumen de tendencias
  String getSummary() {
    final trends = analyzeTrends();
    final trending = trends.trendingCategories
        .map((t) => '${t.name} (${t.growth > 0 ? '+' : ''}${t.growth.toStringAsFixed(1)}%)')
        .join(', ');

    return 'Trending: $trending | Popular tags: ${trends.popularTags.keys.take(5).join(", ")}';
  }
}

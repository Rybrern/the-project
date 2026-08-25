import 'quality_predictor.dart';
import 'category_classifier.dart';
import 'trend_analyzer.dart';

/// Servicio ML integrado
class MLService {
  static final MLService _instance = MLService._internal();

  late final QualityPredictor _qualityPredictor;
  late final CategoryClassifier _categoryClassifier;
  late final TrendAnalyzer _trendAnalyzer;

  factory MLService() => _instance;

  MLService._internal() {
    _qualityPredictor = QualityPredictor();
    _categoryClassifier = CategoryClassifier();
    _trendAnalyzer = TrendAnalyzer();
  }

  /// Acceso a predictor de calidad
  QualityPredictor get qualityPredictor => _qualityPredictor;

  /// Acceso a clasificador
  CategoryClassifier get categoryClassifier => _categoryClassifier;

  /// Acceso a analizador de tendencias
  TrendAnalyzer get trendAnalyzer => _trendAnalyzer;

  /// Pipeline completo: predecir calidad y clasificar
  Future<MLPipelineResult> analyzeWallpaper({
    required int width,
    required int height,
    required int colorCount,
    required double averageLuminance,
    required double contrast,
    required double saturation,
    required List<String> tags,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Predecir calidad
    final qualityResult = await _qualityPredictor.predictQuality(
      width: width,
      height: height,
      colorCount: colorCount,
      averageLuminance: averageLuminance,
      contrast: contrast,
      saturation: saturation,
    );

    // 2. Clasificar categoría
    final categoryResult = await _categoryClassifier.classify(
      tags: tags,
      metadata: metadata ?? {},
    );

    // 3. Registrar para análisis de tendencias
    _trendAnalyzer.recordCategory(categoryResult.primaryCategory);
    _trendAnalyzer.recordTags(categoryResult.features ?? []);

    return MLPipelineResult(
      quality: qualityResult,
      category: categoryResult,
    );
  }

  /// Obtener recomendaciones
  Future<MLRecommendations> getRecommendations() async {
    final trends = _trendAnalyzer.analyzeTrends();
    final predictions = await _trendAnalyzer.predictDemand(daysAhead: 7);

    return MLRecommendations(
      trendingCategories: trends.trendingCategories,
      recommendedSearch: trends.trendingCategories.take(3).map((t) => t.name).toList(),
      predictedDemand: predictions,
    );
  }
}

/// Resultado del pipeline ML completo
class MLPipelineResult {
  const MLPipelineResult({
    required this.quality,
    required this.category,
  });

  final QualityPredictionResult quality;
  final CategoryClassificationResult category;

  /// Score combinado (60% calidad + 40% categoría)
  double get combinedScore {
    return (quality.score * 0.6) + (category.confidence * 0.4);
  }

  /// Debe ser aceptado?
  bool get shouldAccept {
    return combinedScore > 0.65 && category.confidence > 0.4;
  }
}

/// Recomendaciones del sistema ML
class MLRecommendations {
  const MLRecommendations({
    required this.trendingCategories,
    required this.recommendedSearch,
    required this.predictedDemand,
  });

  final List<dynamic> trendingCategories;
  final List<String> recommendedSearch;
  final Map<String, double> predictedDemand;
}

import 'dart:math';

/// Predicción de calidad de wallpaper basada en características
class QualityPredictionResult {
  const QualityPredictionResult({
    required this.score,
    required this.factors,
    required this.confidence,
    this.recommendation,
  });

  /// Score de calidad predicho (0-1)
  final double score;

  /// Factores que influyen (resolución, aspectRatio, colors, etc)
  final Map<String, double> factors;

  /// Confianza de la predicción
  final double confidence;

  /// Recomendación (accepted, review, rejected)
  final String? recommendation;

  @override
  String toString() => 'QualityPredictionResult(score=$score, confidence=$confidence)';
}

/// Predictor de calidad visual
class QualityPredictor {
  // Pesos del modelo
  static const Map<String, double> _weights = {
    'resolution': 0.25,
    'aspect_ratio': 0.15,
    'color_palette': 0.20,
    'clarity': 0.15,
    'contrast': 0.15,
    'saturation': 0.10,
  };

  /// Predice calidad basada en características
  Future<QualityPredictionResult> predictQuality({
    required int width,
    required int height,
    required int colorCount,
    required double averageLuminance,
    required double contrast,
    required double saturation,
  }) async {
    final factors = <String, double>{};

    // 1. Scoring de resolución
    final resScore = _scoreResolution(width, height);
    factors['resolution'] = resScore;

    // 2. Scoring de aspect ratio
    final aspectRatio = width / height;
    final aspectScore = _scoreAspectRatio(aspectRatio);
    factors['aspect_ratio'] = aspectScore;

    // 3. Scoring de paleta de colores
    final colorScore = _scoreColorPalette(colorCount);
    factors['color_palette'] = colorScore;

    // 4. Scoring de claridad
    final clarityScore = _scoreClarity(width, height);
    factors['clarity'] = clarityScore;

    // 5. Scoring de contraste
    factors['contrast'] = contrast.clamp(0.0, 1.0);

    // 6. Scoring de saturación
    factors['saturation'] = saturation.clamp(0.0, 1.0);

    // Calcular score ponderado
    double totalScore = 0.0;
    _weights.forEach((key, weight) {
      totalScore += (factors[key] ?? 0.0) * weight;
    });

    // Confianza basada en consistencia
    final confidence = _calculateConfidence(factors);

    // Recomendación
    String? recommendation;
    if (totalScore > 0.75) {
      recommendation = 'accepted';
    } else if (totalScore > 0.50) {
      recommendation = 'review';
    } else {
      recommendation = 'rejected';
    }

    return QualityPredictionResult(
      score: totalScore.clamp(0.0, 1.0),
      factors: factors,
      confidence: confidence,
      recommendation: recommendation,
    );
  }

  /// Score de resolución (mejor si >= 1920x1080)
  double _scoreResolution(int width, int height) {
    final megapixels = (width * height) / 1000000.0;

    if (megapixels >= 4.0) return 1.0; // 4K o mejor
    if (megapixels >= 2.0) return 0.9; // FHD
    if (megapixels >= 1.5) return 0.7; // HD+
    if (megapixels >= 0.9) return 0.5; // HD
    return 0.2; // Baja resolución
  }

  /// Score de aspect ratio (mejor si 16:9 o 16:10)
  double _scoreAspectRatio(double ratio) {
    const ideal169 = 16.0 / 9.0; // ~1.778
    const ideal1610 = 16.0 / 10.0; // 1.6
    const ideal2163 = 21.0 / 9.0; // ~2.333

    final diff169 = (ratio - ideal169).abs();
    final diff1610 = (ratio - ideal1610).abs();
    final diff2163 = (ratio - ideal2163).abs();

    final minDiff = [diff169, diff1610, diff2163].reduce((a, b) => a < b ? a : b);

    if (minDiff < 0.1) return 1.0;
    if (minDiff < 0.2) return 0.8;
    if (minDiff < 0.4) return 0.6;
    return 0.3;
  }

  /// Score de paleta de colores (más colores = más interesante)
  double _scoreColorPalette(int colorCount) {
    if (colorCount > 200) return 1.0;
    if (colorCount > 100) return 0.9;
    if (colorCount > 50) return 0.75;
    if (colorCount > 20) return 0.5;
    return 0.2;
  }

  /// Score de claridad basado en resolución esperada
  double _scoreClarity(int width, int height) {
    // Más pixeles = potencialmente más detalles
    final megapixels = (width * height) / 1000000.0;

    if (megapixels >= 6.0) return 1.0;
    if (megapixels >= 4.0) return 0.9;
    if (megapixels >= 2.0) return 0.7;
    if (megapixels >= 1.0) return 0.5;
    return 0.2;
  }

  /// Calcula confianza basada en consistencia de factores
  double _calculateConfidence(Map<String, double> factors) {
    if (factors.isEmpty) return 0.0;

    final values = factors.values.toList();
    final mean = values.fold(0.0, (a, b) => a + b) / values.length;
    final variance = values.fold(0.0, (sum, val) => sum + (val - mean) * (val - mean)) / values.length;
    final stdDev = sqrt(variance);

    // Confianza mayor si hay consistencia (bajo std dev)
    return (1.0 - stdDev.clamp(0.0, 1.0)) * 0.9 + 0.1;
  }
}

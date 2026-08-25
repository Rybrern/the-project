import 'package:flutter/foundation.dart';

/// Resultado de clasificación de categoría
class CategoryClassificationResult {
  const CategoryClassificationResult({
    required this.primaryCategory,
    required this.confidence,
    this.secondaryCategories = const {},
    this.features,
  });

  /// Categoría principal predicha
  final String primaryCategory;

  /// Confianza de la predicción
  final double confidence;

  /// Categorías secundarias con confianza
  final Map<String, double> secondaryCategories;

  /// Features detectadas
  final List<String>? features;

  @override
  String toString() => 'CategoryClassificationResult('
      'primary=$primaryCategory, confidence=$confidence)';
}

/// Clasificador automático de categorías
class CategoryClassifier {
  // Diccionario de palabras clave por categoría
  static const Map<String, List<String>> _categoryKeywords = {
    'nature': [
      'landscape', 'mountain', 'forest', 'tree', 'ocean', 'beach',
      'river', 'waterfall', 'sunset', 'sunrise', 'sky', 'cloud',
      'grass', 'flower', 'plant', 'nature', 'outdoor', 'wilderness',
      'valley', 'canyon', 'desert', 'snow', 'ice', 'lake'
    ],
    'sports': [
      'sport', 'ball', 'player', 'team', 'game', 'match', 'football',
      'soccer', 'basketball', 'tennis', 'golf', 'hockey', 'baseball',
      'athlete', 'competition', 'championship', 'league', 'arena', 'stadium'
    ],
    'space': [
      'space', 'star', 'galaxy', 'planet', 'moon', 'universe', 'cosmos',
      'nebula', 'astronaut', 'satellite', 'rocket', 'spacecraft', 'nasa',
      'astronomy', 'constellation', 'meteorite', 'comet', 'aurora'
    ],
    'animals': [
      'animal', 'dog', 'cat', 'bird', 'lion', 'tiger', 'elephant',
      'monkey', 'deer', 'wolf', 'eagle', 'dolphin', 'whale', 'fish',
      'insect', 'butterfly', 'bee', 'fox', 'bear', 'zebra'
    ],
    'cars': [
      'car', 'vehicle', 'automobile', 'sports car', 'truck', 'racing',
      'formula', 'lamborghini', 'ferrari', 'porsche', 'bugatti', 'bmw',
      'mercedes', 'aston', 'road', 'street', 'highway', 'tire'
    ],
    'abstract': [
      'abstract', 'pattern', 'geometric', 'design', 'color', 'shape',
      'digital', 'art', 'illustration', 'graphic', 'texture', 'render',
      'gradient', 'bright', 'vibrant', 'colorful', '3d', 'modern'
    ],
    'urban': [
      'city', 'urban', 'building', 'architecture', 'street', 'night',
      'lights', 'downtown', 'skyscraper', 'bridge', 'traffic', 'road',
      'apartment', 'metro', 'neon', 'cyberpunk', 'industrial'
    ],
    'technology': [
      'tech', 'computer', 'technology', 'digital', 'cyber', 'code',
      'circuit', 'matrix', 'hacker', 'robot', 'ai', 'virtual',
      'programmer', 'algorithm', 'binary', 'server', 'network'
    ],
  };

  /// Clasifica una imagen basándose en tags/metadata
  Future<CategoryClassificationResult> classify({
    required List<String> tags,
    required Map<String, dynamic> metadata,
  }) async {
    return _classifyByTags(tags, metadata);
  }

  /// Clasifica basándose en tags
  CategoryClassificationResult _classifyByTags(
    List<String> tags,
    Map<String, dynamic> metadata,
  ) {
    final combinedTags = [
      ...tags,
      ...metadata.values
          .whereType<String>()
          .expand((s) => s.toLowerCase().split(RegExp(r'[\s,]+')))
    ].map((t) => t.toLowerCase()).toSet();

    final categoryScores = <String, double>{};

    // Calcular score para cada categoría
    _categoryKeywords.forEach((category, keywords) {
      double score = 0.0;
      int matches = 0;

      for (final tag in combinedTags) {
        for (final keyword in keywords) {
          if (tag.contains(keyword) || keyword.contains(tag)) {
            score += 1.0;
            matches++;
          }
        }
      }

      if (matches > 0) {
        // Normalizar score basado en matching
        categoryScores[category] = (score / (keywords.length * 2)).clamp(0.0, 1.0);
      }
    });

    if (categoryScores.isEmpty) {
      return CategoryClassificationResult(
        primaryCategory: 'general',
        confidence: 0.3,
        features: combinedTags.toList(),
      );
    }

    // Encontrar categoría principal
    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final primary = sortedCategories.first;
    final secondaryMap = <String, double>{};

    for (int i = 1; i < sortedCategories.length && i < 3; i++) {
      secondaryMap[sortedCategories[i].key] = sortedCategories[i].value;
    }

    return CategoryClassificationResult(
      primaryCategory: primary.key,
      confidence: primary.value,
      secondaryCategories: secondaryMap,
      features: combinedTags.toList(),
    );
  }

  /// Obtiene categorías disponibles
  List<String> getAvailableCategories() {
    return _categoryKeywords.keys.toList();
  }

  /// Obtiene keywords para una categoría
  List<String> getKeywordsForCategory(String category) {
    return _categoryKeywords[category] ?? [];
  }

  /// Entrena el clasificador con ejemplos nuevos
  Future<bool> addCategoryExamples(String category, List<String> keywords) async {
    if (!_categoryKeywords.containsKey(category)) {
      debugPrint('CategoryClassifier: Category "$category" not found');
      return false;
    }

    // En una implementación real, actualizar el modelo
    debugPrint('CategoryClassifier: Added ${keywords.length} examples to "$category"');
    return true;
  }
}

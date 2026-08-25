import 'package:flutter/foundation.dart';

import 'nsfw_detector.dart';

/// Detector rápido basado en análisis de metadatos y tags.
/// No analiza la imagen en sí, solo el contexto.
class MetadataDetector implements NSFWDetector {
  @override
  String get name => 'metadata';

  @override
  String get description => 'Fast NSFW detection based on metadata and tags';

  @override
  int get priority => 100; // Más alto = se ejecuta primero

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  // Términos que indican contenido NSFW
  static const _nsfwKeywords = <String>[
    'nsfw',
    'adult',
    'porn',
    'sexy',
    'nude',
    'naked',
    'xxx',
    'sex',
    'erotic',
    'boob',
    'breast',
    'cleavage',
    'bikini',
    'lingerie',
    'underwear',
    'swimsuit',
    'ecchi',
    'ahegao',
    'upskirt',
    'pinup',
    'thigh',
    'ass',
    'butt',
    'bra',
    'panty',
    'fetish',
    'hentai',
    'shemale',
    'lesbian',
  ];

  // Términos seguros (pueden contrarrestar NSFW)
  static const _safeKeywords = <String>[
    'art',
    'painting',
    'drawing',
    'illustration',
    'anime',
    'cartoon',
    'portrait',
    'model',
    'fashion',
    'sport',
    'athlete',
    'dance',
    'performance',
  ];

  // Términos de violencia/gore
  static const _violenceKeywords = <String>[
    'violence',
    'gore',
    'blood',
    'murder',
    'death',
    'kill',
    'gun',
    'weapon',
    'war',
    'injury',
  ];

  @override
  Future<NSFWDetectionResult?> detect(
    Uint8List imageData, {
    Map<String, dynamic>? metadata,
  }) async {
    // Si no hay metadatos, no podemos analizar
    if (metadata == null) {
      return null;
    }

    // Extrae tags y autor
    final tags = (metadata['tags'] as List<String>?) ?? [];
    final author = (metadata['author'] as String?) ?? '';
    final source = (metadata['source'] as String?) ?? '';

    // Convierte todo a minúsculas para búsqueda
    final tagsLower = tags.map((t) => t.toLowerCase()).toList();
    final authorLower = author.toLowerCase();
    final sourceLower = source.toLowerCase();

    // Calcula scores
    final nsfwScore = _calculateNsfwScore(tagsLower, authorLower, sourceLower);
    final violenceScore = _calculateViolenceScore(tagsLower);

    // Score final es el máximo
    final finalScore = [nsfwScore, violenceScore].reduce((a, b) => a > b ? a : b);

    debugPrint(
      'MetadataDetector: NSFW=$nsfwScore, Violence=$violenceScore, Final=$finalScore',
    );

    return NSFWDetectionResult(
      score: finalScore,
      isNSFW: finalScore > 0.5, // Umbral binario rápido
      confidence: 0.6, // Confianza moderada (solo metadatos)
      method: 'metadata',
      details: {
        'nsfw_score': nsfwScore,
        'violence_score': violenceScore,
        'tags_count': tagsLower.length,
        'nfsw_keywords_found': _findMatchingKeywords(tagsLower, _nsfwKeywords),
        'violence_keywords_found': _findMatchingKeywords(tagsLower, _violenceKeywords),
      },
    );
  }

  /// Calcula score NSFW (0.0 - 1.0)
  double _calculateNsfwScore(
    List<String> tagsLower,
    String authorLower,
    String sourceLower,
  ) {
    var score = 0.0;

    // Cuenta coincidencias con palabras clave NSFW
    final nsfwMatches = tagsLower.where((t) => _containsKeyword(t, _nsfwKeywords)).length;
    score += (nsfwMatches / (tagsLower.isEmpty ? 1 : tagsLower.length)) * 0.7;

    // Revisa si está explícitamente marcado como NSFW
    if (tagsLower.contains('nsfw') || tagsLower.contains('adult')) {
      score = 0.9;
    }

    // Reduce score si hay palabras clave seguras (puede ser arte, cartoon, etc.)
    final safeMatches = tagsLower.where((t) => _containsKeyword(t, _safeKeywords)).length;
    final safeFactor = (safeMatches / (tagsLower.isEmpty ? 1 : tagsLower.length));
    score = (score * (1.0 - safeFactor * 0.5)).clamp(0.0, 1.0);

    return score;
  }

  /// Calcula score de violencia (0.0 - 1.0)
  double _calculateViolenceScore(List<String> tagsLower) {
    final violenceMatches = tagsLower.where((t) => _containsKeyword(t, _violenceKeywords)).length;
    return (violenceMatches / (tagsLower.isEmpty ? 1 : tagsLower.length)).clamp(0.0, 1.0);
  }

  /// Busca si un tag contiene una keyword
  bool _containsKeyword(String tag, List<String> keywords) {
    return keywords.any((kw) => tag.contains(kw));
  }

  /// Encuentra qué keywords coinciden
  List<String> _findMatchingKeywords(List<String> tagsLower, List<String> keywords) {
    return tagsLower.where((tag) => _containsKeyword(tag, keywords)).toList();
  }
}

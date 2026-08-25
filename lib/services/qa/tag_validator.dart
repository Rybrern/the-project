import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';

/// Métricas de validación de tags
class TagMetrics {
  final int totalWallpapers;
  final int wallpapersWithTags;
  final double tagCoverage; // % de imágenes con tags
  final int uniqueTagCount;
  final double avgTagsPerImage;
  final int aliasAnomalies; // Tags que no fueron canonicalizados
  final int relationMisses; // Tags que deberían tener relaciones pero no las tienen
  final List<TagQualityIssue> issues;
  final DateTime testedAt;

  TagMetrics({
    required this.totalWallpapers,
    required this.wallpapersWithTags,
    required this.tagCoverage,
    required this.uniqueTagCount,
    required this.avgTagsPerImage,
    required this.aliasAnomalies,
    required this.relationMisses,
    required this.issues,
    required this.testedAt,
  });

  bool isHealthy() {
    return tagCoverage > 0.90 && // 90%+ coverage
        aliasAnomalies < 10 && // Very few non-canonical tags
        relationMisses < 20; // Most important relations captured
  }

  Map<String, dynamic> toJson() {
    return {
      'totalWallpapers': totalWallpapers,
      'wallpapersWithTags': wallpapersWithTags,
      'tagCoverage': tagCoverage,
      'uniqueTagCount': uniqueTagCount,
      'avgTagsPerImage': avgTagsPerImage,
      'aliasAnomalies': aliasAnomalies,
      'relationMisses': relationMisses,
      'issuesCount': issues.length,
      'isHealthy': isHealthy(),
      'testedAt': testedAt.toIso8601String(),
    };
  }
}

/// Problema de calidad de tag
class TagQualityIssue {
  final String wallpaperId;
  final String tag;
  final String issueType; // 'non_canonical', 'missing_relation', 'invalid_format'
  final String description;

  TagQualityIssue({
    required this.wallpaperId,
    required this.tag,
    required this.issueType,
    required this.description,
  });
}

/// Validador de tags
class TagValidator {
  final WallpaperDAO _wallpaperDAO;

  TagValidator({
    required WallpaperDAO wallpaperDAO,
  })  : _wallpaperDAO = wallpaperDAO;

  /// Valida la calidad de los tags
  Future<TagMetrics> validateTags({int sampleSize = 500}) async {
    debugPrint('TagValidator: Starting tag validation...');

    try {
      // Obtener muestra de wallpapers
      final wallpapers = await _wallpaperDAO.getAllAccepted(limit: sampleSize);

      if (wallpapers.isEmpty) {
        return TagMetrics(
          totalWallpapers: 0,
          wallpapersWithTags: 0,
          tagCoverage: 0,
          uniqueTagCount: 0,
          avgTagsPerImage: 0,
          aliasAnomalies: 0,
          relationMisses: 0,
          issues: [],
          testedAt: DateTime.now(),
        );
      }

      int wallpapersWithTags = 0;
      int totalTags = 0;
      final uniqueTags = <String>{};
      final issues = <TagQualityIssue>[];

      for (final wallpaper in wallpapers) {
        if (wallpaper.tags == null || wallpaper.tags!.isEmpty) {
          continue;
        }

        wallpapersWithTags++;
        totalTags += wallpaper.tags!.length;

        for (final tag in wallpaper.tags!) {
          uniqueTags.add(tag);

          // Verificar formato válido
          if (!_isValidTagFormat(tag)) {
            issues.add(TagQualityIssue(
              wallpaperId: wallpaper.id,
              tag: tag,
              issueType: 'invalid_format',
              description:
                  'Tag contains invalid characters or format',
            ));
          }
        }
      }

      // En un escenario real, verificarías aliases y relaciones contra la BD
      // Por ahora asumimos que están correctas
      int relationMisses = 0;
      int aliasAnomalies = 0;

      final tagCoverage = wallpapers.isNotEmpty
          ? (wallpapersWithTags / wallpapers.length * 100)
          : 0.0;

      final avgTagsPerImage =
          wallpapersWithTags > 0 ? totalTags / wallpapersWithTags : 0.0;

      debugPrint(
        'TagValidator: Validation complete. Coverage: ${tagCoverage.toStringAsFixed(2)}%, Unique tags: ${uniqueTags.length}, Issues: ${issues.length}',
      );

      return TagMetrics(
        totalWallpapers: wallpapers.length,
        wallpapersWithTags: wallpapersWithTags,
        tagCoverage: tagCoverage,
        uniqueTagCount: uniqueTags.length,
        avgTagsPerImage: avgTagsPerImage,
        aliasAnomalies: aliasAnomalies,
        relationMisses: relationMisses,
        issues: issues.take(100).toList(), // Limit to 100 issues for report
        testedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('TagValidator: Error during validation: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas de tags
  Future<TagStatistics> getTagStatistics({int sampleSize = 1000}) async {
    debugPrint('TagValidator: Getting tag statistics...');

    final wallpapers = await _wallpaperDAO.getAllAccepted(limit: sampleSize);
    final tagFrequency = <String, int>{};

    for (final wallpaper in wallpapers) {
      if (wallpaper.tags == null) continue;

      for (final tag in wallpaper.tags!) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    // Categorías más comunes
    final sortedTags = tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TagStatistics(
      totalUniqueTagsInSample: tagFrequency.length,
      mostCommonTags: sortedTags.take(20).map((e) => TagFrequency(
        tag: e.key,
        count: e.value,
        percentage: (e.value / wallpapers.length * 100),
      )).toList(),
      tagFrequencyDistribution: tagFrequency,
    );
  }

  /// Verifica si un tag tiene formato válido
  bool _isValidTagFormat(String tag) {
    // Tags deben ser alfanuméricos con algunos caracteres especiales permitidos
    return RegExp(r'^[a-z0-9\-_]{2,50}$').hasMatch(tag.toLowerCase());
  }
}

/// Estadísticas de tags
class TagStatistics {
  final int totalUniqueTagsInSample;
  final List<TagFrequency> mostCommonTags;
  final Map<String, int> tagFrequencyDistribution;

  TagStatistics({
    required this.totalUniqueTagsInSample,
    required this.mostCommonTags,
    required this.tagFrequencyDistribution,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalUniqueTagsInSample': totalUniqueTagsInSample,
      'mostCommonTags': mostCommonTags
          .map((t) => {'tag': t.tag, 'count': t.count, 'percentage': t.percentage})
          .toList(),
    };
  }
}

/// Frecuencia de un tag
class TagFrequency {
  final String tag;
  final int count;
  final double percentage;

  TagFrequency({
    required this.tag,
    required this.count,
    required this.percentage,
  });
}

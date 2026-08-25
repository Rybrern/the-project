import 'package:flutter/foundation.dart';

import '../batch_config.dart';
import '../../tag_normalization/tag_seeder.dart';
import '../../../database/app_database.dart';
import '../../../models/wallpaper.dart' show Wallpaper;
import 'pipeline_stage.dart';

/// Stage 5: Clasifica los wallpapers en categorías y subcategorías.
/// Utiliza source, tags y otros metadatos para determinar la categoría.
/// También siembra tags en la base de datos v6 desde metadatos de la API.
class ClassificationStage implements PipelineStage {
  final AppDatabase? appDatabase;
  TagSeeder? _tagSeeder;

  ClassificationStage({this.appDatabase}) {
    if (appDatabase != null) {
      _tagSeeder = TagSeeder(appDatabase);
    }
  }
  @override
  String get name => 'classification';

  @override
  String get description => 'Classify wallpapers into categories';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    for (final candidate in candidates) {
      try {
        // Obtiene tags de metadatos
        final tags = candidate.getMetadata('tags') as List<String>? ?? [];

        // Intenta clasificar basándose en tags y fuente
        final classification = _classify(candidate.source, tags);

        candidate.updateMetadata('primary_category', classification['primary']);
        candidate.updateMetadata('subcategory', classification['secondary']);

        // Seed tags into the database if database is available
        if (_tagSeeder != null && tags.isNotEmpty) {
          // Reconstruct minimal wallpaper object from metadata for tag seeding
          final wallpaper = _buildWallpaperFromCandidate(candidate);
          await _tagSeeder!.seedTagsFromImage(wallpaper);
        }

        debugPrint(
          'ClassificationStage: Classified as ${classification['primary']}/${classification['secondary']}',
        );
      } catch (e) {
        // Si falla la clasificación, usa default
        candidate.updateMetadata('primary_category', 'general');
        candidate.updateMetadata('subcategory', null);
        debugPrint('ClassificationStage: Classification error: $e');
      }
    }

    return candidates;
  }

  /// Clasifica un candidato basándose en source y tags
  Map<String, String?> _classify(String source, List<String> tags) {
    // Convierte tags a minúsculas para búsqueda
    final lowerTags = tags.map((t) => t.toLowerCase()).toList();
    final tagsString = lowerTags.join(' ');

    // Deportes
    if (_matchesSport(tagsString)) {
      final sport = _determineSport(tagsString);
      return {
        'primary': 'deportes',
        'secondary': sport,
      };
    }

    // Naturaleza
    if (tagsString.contains('nature') ||
        tagsString.contains('landscape') ||
        tagsString.contains('forest') ||
        tagsString.contains('mountain')) {
      return {'primary': 'naturaleza', 'secondary': null};
    }

    // Espacio
    if (tagsString.contains('space') ||
        tagsString.contains('galaxy') ||
        tagsString.contains('planet') ||
        tagsString.contains('astronaut')) {
      return {'primary': 'espacio', 'secondary': null};
    }

    // Animales
    if (tagsString.contains('animal') ||
        tagsString.contains('wildlife') ||
        tagsString.contains('dog') ||
        tagsString.contains('cat')) {
      return {'primary': 'animales', 'secondary': null};
    }

    // Autos/Motos
    if (tagsString.contains('car') ||
        tagsString.contains('motorcycle') ||
        tagsString.contains('auto') ||
        tagsString.contains('vehicle')) {
      return {'primary': 'autos-motos', 'secondary': null};
    }

    // Películas/Series
    if (tagsString.contains('movie') ||
        tagsString.contains('film') ||
        tagsString.contains('cinema') ||
        tagsString.contains('tv')) {
      return {'primary': 'peliculas-series', 'secondary': null};
    }

    // Anime
    if (tagsString.contains('anime') || tagsString.contains('manga')) {
      return {'primary': 'anime', 'secondary': null};
    }

    // Videojuegos
    if (tagsString.contains('game') ||
        tagsString.contains('gaming') ||
        tagsString.contains('video game')) {
      return {'primary': 'videojuegos', 'secondary': null};
    }

    // Default
    return {'primary': 'general', 'secondary': null};
  }

  bool _matchesSport(String tagsString) {
    return tagsString.contains('sport') ||
        tagsString.contains('football') ||
        tagsString.contains('soccer') ||
        tagsString.contains('basketball') ||
        tagsString.contains('tennis') ||
        tagsString.contains('athlete') ||
        tagsString.contains('player') ||
        tagsString.contains('messi') ||
        tagsString.contains('ronaldo') ||
        tagsString.contains('nba') ||
        tagsString.contains('nfl') ||
        tagsString.contains('f1');
  }

  String _determineSport(String tagsString) {
    // Fútbol
    if (tagsString.contains('football') ||
        tagsString.contains('soccer') ||
        tagsString.contains('messi') ||
        tagsString.contains('ronaldo') ||
        tagsString.contains('champion league')) {
      return 'futbol';
    }

    // Motor
    if (tagsString.contains('f1') ||
        tagsString.contains('motogp') ||
        tagsString.contains('nascar') ||
        tagsString.contains('formula 1') ||
        tagsString.contains('racing') ||
        tagsString.contains('rally')) {
      return 'motor';
    }

    // Basketball
    if (tagsString.contains('basketball') ||
        tagsString.contains('nba') ||
        tagsString.contains('lebron')) {
      return 'basquetbol';
    }

    // Tennis
    if (tagsString.contains('tennis') ||
        tagsString.contains('wimbledon')) {
      return 'tenis';
    }

    // Default: otros deportes
    return 'otros-deportes';
  }

  /// Builds a minimal Wallpaper object from PipelineCandidate metadata
  /// Used for tag seeding during classification stage
  Wallpaper _buildWallpaperFromCandidate(PipelineCandidate candidate) {
    final tags = candidate.getMetadata('tags') as List<String>? ?? [];
    final aspectRatio = (candidate.getMetadata('aspect_ratio') as num?)?.toDouble() ?? 1.0;

    return Wallpaper(
      id: candidate.sourceId,
      thumbnailUrl: candidate.url,
      fullUrl: candidate.url,
      author: candidate.getMetadata('author') as String? ?? 'Unknown',
      category: candidate.getMetadata('category') as String? ?? 'general',
      aspectRatio: aspectRatio,
      source: candidate.source,
      sourceId: candidate.sourceId,
      tags: tags.isNotEmpty ? tags : null,
      primaryCategory: candidate.getMetadata('primary_category') as String?,
      subcategory: candidate.getMetadata('subcategory') as String?,
    );
  }
}

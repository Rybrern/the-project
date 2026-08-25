import 'package:flutter/foundation.dart';
import '../../../database/daos/daos.dart';
import '../../../services/search/search_service.dart';
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Popula el índice de búsqueda con información de los wallpapers procesados
/// Facilita búsquedas rápidas sin escanear toda la tabla de wallpapers
class SearchIndexStage implements PipelineStage {
  SearchIndexStage({
    required this.wallpaperDAO,
    required this.searchIndexDAO,
    required this.tagDAO,
    required this.tagRelationDAO,
  });

  final WallpaperDAO wallpaperDAO;
  final SearchIndexDAO searchIndexDAO;
  final TagDAO tagDAO;
  final TagRelationDAO tagRelationDAO;

  @override
  String get name => 'search_index';

  @override
  String get description => 'Populating search index';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final entriesToInsert = <SearchIndexEntry>[];

    for (final candidate in candidates) {
      try {
        // Solo indexar candidatos aceptados
        if (candidate.isRejected) {
          continue;
        }

        // Obtener el wallpaper guardado en base de datos
        final wallpaperId = candidate.getMetadata('wallpaper_id') as String?;
        if (wallpaperId == null) {
          debugPrint('SearchIndexStage: No wallpaper_id for candidate ${candidate.url}');
          continue;
        }

        final wallpaper = await wallpaperDAO.getById(wallpaperId);
        if (wallpaper == null) {
          debugPrint('SearchIndexStage: Wallpaper $wallpaperId not found');
          continue;
        }

        // Crear servicio de búsqueda para normalización
        final searchService = SearchService(
          searchIndexDAO: searchIndexDAO,
          wallpaperDAO: wallpaperDAO,
          animatedWallpaperDAO: null as dynamic,
          tagDAO: tagDAO,
          tagRelationDAO: tagRelationDAO,
        );

        // Indexar categoría
        if (wallpaper.category.isNotEmpty) {
          final normalized = searchService.normalizeText(wallpaper.category);
          entriesToInsert.add(_createSearchEntry(
            wallpaperId: wallpaperId,
            queryText: normalized,
            entityType: 'category',
            relevance: 1.5, // Mayor relevancia para categorías
          ));
        }

        // Indexar tags
        if (wallpaper.tags != null) {
          for (final tag in wallpaper.tags!) {
            final normalized = searchService.normalizeText(tag);
            entriesToInsert.add(_createSearchEntry(
              wallpaperId: wallpaperId,
              queryText: normalized,
              entityType: 'tag',
              relevance: 1.0,
            ));
          }
        }

        // Indexar metadatos de entidades
        if (wallpaper.entityMetadata != null) {
          wallpaper.entityMetadata!.forEach((key, value) {
            if (value is String && value.isNotEmpty) {
              final normalized = searchService.normalizeText(value);
              entriesToInsert.add(_createSearchEntry(
                wallpaperId: wallpaperId,
                queryText: normalized,
                entityType: key,
                relevance: 1.3,
              ));
            }
          });
        }

        // Indexar subcategoría
        if (wallpaper.subcategory != null && wallpaper.subcategory!.isNotEmpty) {
          final normalized = searchService.normalizeText(wallpaper.subcategory!);
          entriesToInsert.add(_createSearchEntry(
            wallpaperId: wallpaperId,
            queryText: normalized,
            entityType: 'subcategory',
            relevance: 1.2,
          ));
        }

        debugPrint('SearchIndexStage: Indexed $wallpaperId with ${entriesToInsert.length} entries');
      } catch (e) {
        debugPrint('SearchIndexStage: Error indexing candidate: $e');
        // Continuar con el siguiente candidato
      }
    }

    // Insertar todas las entradas en batch
    if (entriesToInsert.isNotEmpty) {
      try {
        await searchIndexDAO.insertBatch(entriesToInsert);
        debugPrint('SearchIndexStage: Inserted ${entriesToInsert.length} index entries');
      } catch (e) {
        debugPrint('SearchIndexStage: Error inserting entries: $e');
      }
    }

    return candidates;
  }

  /// Crea una entrada de índice de búsqueda
  SearchIndexEntry _createSearchEntry({
    required String wallpaperId,
    required String queryText,
    required String entityType,
    required double relevance,
  }) {
    return SearchIndexEntry(
      id: 0, // Se auto-genera en la DB
      wallpaperId: wallpaperId,
      queryText: queryText,
      entityType: entityType,
      relevance: relevance,
      createdAt: DateTime.now(),
    );
  }
}

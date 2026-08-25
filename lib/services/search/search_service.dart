import '../../database/daos/daos.dart';
import '../../models/wallpaper.dart';

/// Servicio de búsqueda con normalización de texto, fuzzy matching e integración con índices
class SearchService {
  final SearchIndexDAO _searchIndexDAO;
  final WallpaperDAO _wallpaperDAO;
  final AnimatedWallpaperDAO _animatedWallpaperDAO;

  SearchService({
    required SearchIndexDAO searchIndexDAO,
    required WallpaperDAO wallpaperDAO,
    required AnimatedWallpaperDAO animatedWallpaperDAO,
  })  : _searchIndexDAO = searchIndexDAO,
        _wallpaperDAO = wallpaperDAO,
        _animatedWallpaperDAO = animatedWallpaperDAO;

  /// Palabras vacías en español que no aportan valor de búsqueda
  static const _stopWords = {
    'el', 'la', 'de', 'y', 'a', 'en', 'un', 'una', 'los', 'las',
    'del', 'al', 'con', 'por', 'para', 'se', 'su', 'es', 'son', 'está',
    'están', 'fue', 'fueron', 'sido', 'siendo', 'he', 'has', 'ha',
    'hemos', 'habéis', 'han', 'haya', 'hayas', 'hayamos', 'hayáis',
  };

  /// Normaliza texto: conversión a minúsculas, eliminación de acentos y caracteres especiales
  String normalizeText(String text) {
    // Convertir a minúsculas
    text = text.toLowerCase();

    // Eliminar acentos (usando mapa simple)
    const accentMap = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ñ': 'n', 'ü': 'u',
    };
    accentMap.forEach((accented, clean) {
      text = text.replaceAll(accented, clean);
    });

    // Eliminar caracteres especiales, mantener solo letras, números y espacios
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // Normalizar espacios en blanco
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Tokeniza un texto en palabras, eliminando palabras vacías
  List<String> _tokenize(String text) {
    final normalized = normalizeText(text);
    return normalized
        .split(' ')
        .where((token) => token.isNotEmpty && !_stopWords.contains(token))
        .toList();
  }

  /// Calcula relevancia basada en tipo de entidad y coincidencias exactas
  double _calculateRelevance({
    required String entityType,
    required bool isExactMatch,
  }) {
    double relevance = 1.0;

    // Aumentar relevancia para tipos de entidad más específicos
    switch (entityType) {
      case 'player':
        relevance *= 1.5;
      case 'team':
        relevance *= 1.3;
      case 'tag':
        relevance *= 1.1;
      default:
        break;
    }

    // Duplicar relevancia para coincidencias exactas
    if (isExactMatch) {
      relevance *= 2.0;
    }

    return relevance;
  }

  /// Búsqueda exacta en índice (sin fuzzy matching)
  Future<List<Wallpaper>> searchExact(
    String query, {
    String? entityType,
    int limit = 50,
  }) async {
    final normalized = normalizeText(query);
    if (normalized.isEmpty) return [];

    // Buscar en índice
    final wallpaperIds = await _searchIndexDAO.search(
      normalized,
      entityType: entityType,
    );

    if (wallpaperIds.isEmpty) return [];

    // Obtener wallpapers completos
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIds.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }
    return wallpapers;
  }

  /// Búsqueda fuzzy (LIKE) en índice
  Future<List<Wallpaper>> searchFuzzy(
    String query, {
    String? entityType,
    int limit = 50,
  }) async {
    final normalized = normalizeText(query);
    if (normalized.isEmpty) return [];

    // Buscar en índice con fuzzy matching
    final wallpaperIds = await _searchIndexDAO.searchFuzzy(
      normalized,
      entityType: entityType,
    );

    if (wallpaperIds.isEmpty) return [];

    // Obtener wallpapers completos
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIds.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }
    return wallpapers;
  }

  /// Búsqueda por tokens individuales
  Future<List<Wallpaper>> searchByTokens(
    String query, {
    String? entityType,
    int limit = 50,
  }) async {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return [];

    // Buscar cada token
    final wallpaperIdSet = <String>{};
    for (final token in tokens) {
      final ids = await _searchIndexDAO.searchFuzzy(
        token,
        entityType: entityType,
      );
      wallpaperIdSet.addAll(ids);
    }

    if (wallpaperIdSet.isEmpty) return [];

    // Obtener wallpapers completos
    final wallpapers = <Wallpaper>[];
    for (final id in wallpaperIdSet.take(limit)) {
      final wallpaper = await _wallpaperDAO.getById(id);
      if (wallpaper != null) {
        wallpapers.add(wallpaper);
      }
    }
    return wallpapers;
  }

  /// Obtener sugerencias de autocompletado
  Future<List<String>> getAutocompleteSuggestions(
    String prefix, {
    int limit = 10,
  }) async {
    final normalized = normalizeText(prefix);
    if (normalized.isEmpty) return [];

    return await _searchIndexDAO.getAutocompleteSuggestions(
      normalized,
      limit: limit,
    );
  }

  /// Reconstruir índice de búsqueda a partir de wallpapers aceptados
  Future<void> rebuildSearchIndex() async {
    await _searchIndexDAO.rebuildIndex();

    // Obtener todos los wallpapers aceptados
    final allWallpapers = await _wallpaperDAO.getAllAccepted();

    // Construir entradas de índice
    final entries = <SearchIndexEntry>[];
    for (final wallpaper in allWallpapers) {
      // Indexar nombre/categoría
      if (wallpaper.category.isNotEmpty) {
        final normalized = normalizeText(wallpaper.category);
        entries.add(SearchIndexEntry(
          id: 0,
          wallpaperId: wallpaper.id,
          queryText: normalized,
          entityType: 'category',
          relevance: _calculateRelevance(
            entityType: 'category',
            isExactMatch: true,
          ),
          createdAt: DateTime.now(),
        ));
      }

      // Indexar tags individuales
      if (wallpaper.tags != null) {
        for (final tag in wallpaper.tags!) {
          final normalized = normalizeText(tag);
          entries.add(SearchIndexEntry(
            id: 0,
            wallpaperId: wallpaper.id,
            queryText: normalized,
            entityType: 'tag',
            relevance: _calculateRelevance(
              entityType: 'tag',
              isExactMatch: false,
            ),
            createdAt: DateTime.now(),
          ));
        }
      }

      // Indexar metadatos de entidades (nombres de jugadores, equipos, etc.)
      if (wallpaper.entityMetadata != null) {
        wallpaper.entityMetadata!.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            final normalized = normalizeText(value);
            entries.add(SearchIndexEntry(
              id: 0,
              wallpaperId: wallpaper.id,
              queryText: normalized,
              entityType: key, // 'player', 'team', etc.
              relevance: _calculateRelevance(
                entityType: key,
                isExactMatch: true,
              ),
              createdAt: DateTime.now(),
            ));
          }
        });
      }
    }

    // Insertar todas las entradas en batch
    if (entries.isNotEmpty) {
      await _searchIndexDAO.insertBatch(entries);
    }
  }
}

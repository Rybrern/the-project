import '../../database/daos/daos.dart';
import '../../database/app_database.dart';

/// Servicio para crear aliases de tags (variaciones de búsqueda)
/// Esto permite que "messi", "leo messi", "lionel messi" encuentren el mismo tag
class TagAliasSeedingService {
  final AppDatabase _appDatabase;
  late TagDAO _tagDAO;
  late TagAliasDAO _aliasDAO;

  TagAliasSeedingService(this._appDatabase) {
    _tagDAO = TagDAO(_appDatabase);
    _aliasDAO = TagAliasDAO(_appDatabase);
  }

  /// Ejecuta el seeding de aliases
  Future<void> seed() async {
    try {
      print('🌱 Iniciando seeding de aliases...');

      // Obtener tags existentes
      final tagMap = await _getAllTagsMap();
      if (tagMap.isEmpty) {
        print('⚠️ No hay tags en la BD. Ejecuta TagSeedingService primero.');
        return;
      }

      // Paso 1: Crear aliases para personas famosas
      print('  • Creando aliases de deportistas...');
      await _seedPersonAliases(tagMap);

      // Paso 2: Crear aliases para equipos
      print('  • Creando aliases de equipos...');
      await _seedTeamAliases(tagMap);

      // Paso 3: Crear aliases para competiciones
      print('  • Creando aliases de competiciones...');
      await _seedCompetitionAliases(tagMap);

      // Paso 4: Crear aliases genéricos
      print('  • Creando aliases genéricos...');
      await _seedGenericAliases(tagMap);

      print('✅ Seeding de aliases completado');
      final aliasCount = await _aliasDAO.count();
      print('   Total de aliases: $aliasCount');
    } catch (e) {
      print('❌ Error durante seeding de aliases: $e');
      rethrow;
    }
  }

  /// Obtiene todos los tags en un mapa para búsqueda rápida
  Future<Map<String, int>> _getAllTagsMap() async {
    final allTags = await _tagDAO.getAll(limit: 10000);
    final map = <String, int>{};
    for (final tag in allTags) {
      map[tag.canonicalName] = tag.id;
    }
    return map;
  }

  /// Crea aliases para personas famosas
  Future<void> _seedPersonAliases(Map<String, int> tagMap) async {
    final aliases = <TagAlias>[];

    // Ejemplo: Lionel Messi
    // Nota: Este es un ejemplo. En producción tendrías miles de personas.
    // Por ahora, solo creamos estructura de ejemplo.

    const personAliases = [
      ('lionel-messi', ['messi', 'leo messi', 'lionel andres messi', 'messi10', 'm10']),
      // Más personas pueden agregarse fácilmente
    ];

    for (final (canonicalName, aliasTexts) in personAliases) {
      final tagId = tagMap[canonicalName];
      if (tagId == null) continue;

      for (final aliasText in aliasTexts) {
        aliases.add(TagAlias(
          id: 0,
          tagId: tagId,
          aliasText: aliasText,
          normalizedAlias: _normalizeAlias(aliasText),
          source: 'manual_seeding',
          confidence: 0.9,
          createdAt: DateTime.now(),
        ));
      }
    }

    if (aliases.isNotEmpty) {
      await _aliasDAO.insertBatch(aliases);
    }
  }

  /// Crea aliases para equipos
  Future<void> _seedTeamAliases(Map<String, int> tagMap) async {
    final aliases = <TagAlias>[];

    const teamAliases = [
      ('real-madrid', ['real madrid', 'rm', 'madrid', 'los blancos']),
      ('barcelona', ['barca', 'barcelona fc', 'fcb']),
      ('manchester-city', ['man city', 'manchester city', 'city']),
      ('liverpool', ['lfc', 'liverpool fc']),
      ('psg', ['paris saint germain', 'psg', 'paris sg']),
      ('ferrari', ['ferrari team', 'scuderia ferrari', 'cavallino']),
      ('red-bull', ['red bull racing', 'rbr']),
      ('inter-miami', ['inter miami cf', 'miami']),
    ];

    for (final (canonicalName, aliasTexts) in teamAliases) {
      final tagId = tagMap[canonicalName];
      if (tagId == null) continue;

      for (final aliasText in aliasTexts) {
        aliases.add(TagAlias(
          id: 0,
          tagId: tagId,
          aliasText: aliasText,
          normalizedAlias: _normalizeAlias(aliasText),
          source: 'manual_seeding',
          confidence: 0.85,
          createdAt: DateTime.now(),
        ));
      }
    }

    if (aliases.isNotEmpty) {
      await _aliasDAO.insertBatch(aliases);
    }
  }

  /// Crea aliases para competiciones y ligas
  Future<void> _seedCompetitionAliases(Map<String, int> tagMap) async {
    final aliases = <TagAlias>[];

    const competitionAliases = [
      ('formula-1', ['f1', 'formula one', 'f-1']),
      ('champions-league', ['champs league', 'ucl', 'champions']),
      ('premier-league', ['pl', 'epl', 'english premier league']),
      ('motogp', ['moto gp', 'moto-gp', 'motorcycle racing']),
      ('nba', ['nba basketball', 'national basketball']),
    ];

    for (final (canonicalName, aliasTexts) in competitionAliases) {
      final tagId = tagMap[canonicalName];
      if (tagId == null) continue;

      for (final aliasText in aliasTexts) {
        aliases.add(TagAlias(
          id: 0,
          tagId: tagId,
          aliasText: aliasText,
          normalizedAlias: _normalizeAlias(aliasText),
          source: 'manual_seeding',
          confidence: 0.88,
          createdAt: DateTime.now(),
        ));
      }
    }

    if (aliases.isNotEmpty) {
      await _aliasDAO.insertBatch(aliases);
    }
  }

  /// Crea aliases para tags genéricos
  Future<void> _seedGenericAliases(Map<String, int> tagMap) async {
    final aliases = <TagAlias>[];

    const genericAliases = [
      ('cyberpunk', ['cyber punk', 'cybernetic']),
      ('sci-fi', ['science fiction', 'scifi', 'sf']),
      ('fantasy', ['fantasy world', 'fantasy art']),
      ('abstract', ['abstract art', 'abstraction']),
      ('minimalist', ['minimal', 'minimalism']),
      ('digital-art', ['digital', 'digital artwork']),
    ];

    for (final (canonicalName, aliasTexts) in genericAliases) {
      final tagId = tagMap[canonicalName];
      if (tagId == null) continue;

      for (final aliasText in aliasTexts) {
        aliases.add(TagAlias(
          id: 0,
          tagId: tagId,
          aliasText: aliasText,
          normalizedAlias: _normalizeAlias(aliasText),
          source: 'manual_seeding',
          confidence: 0.80,
          createdAt: DateTime.now(),
        ));
      }
    }

    if (aliases.isNotEmpty) {
      await _aliasDAO.insertBatch(aliases);
    }
  }

  /// Normaliza un alias para búsqueda
  String _normalizeAlias(String alias) {
    return alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

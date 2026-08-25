import '../../database/daos/daos.dart';
import '../../database/app_database.dart';
import '../../models/default_categories.dart';

/// Servicio para popular la base de datos con tags iniciales
/// Ejecutar una sola vez después de la migración 006
class TagSeedingService {
  final AppDatabase _appDatabase;
  late TagDAO _tagDAO;
  late TagAliasDAO _aliasDAO;
  late TagRelationDAO _relationDAO;

  TagSeedingService(this._appDatabase) {
    _tagDAO = TagDAO(_appDatabase);
    _aliasDAO = TagAliasDAO(_appDatabase);
    _relationDAO = TagRelationDAO(_appDatabase);
  }

  /// Ejecuta el seeding completo
  /// Retorna true si fue exitoso, false si ya estaba poblado
  Future<bool> seed() async {
    try {
      // Verificar si ya hay tags (evitar duplicados)
      final tagCount = await _tagDAO.count();
      if (tagCount > 0) {
        print('⚠️ Base de datos de tags ya poblada ($tagCount tags existentes)');
        return false;
      }

      print('🌱 Iniciando seeding de tags...');

      // Paso 1: Crear tags de categorías
      print('  • Creando tags de categorías...');
      await _seedCategoryTags();

      // Paso 2: Crear tags de deportes y subcategorías
      print('  • Creando tags de deportes...');
      await _seedSportsTags();

      // Paso 3: Crear tags genéricos y conceptos
      print('  • Creando tags genéricos...');
      await _seedGenericTags();

      // Paso 4: Crear relaciones iniciales
      print('  • Creando relaciones entre tags...');
      await _seedRelations();

      print('✅ Seeding completado exitosamente');
      final finalCount = await _tagDAO.count();
      print('   Total de tags creados: $finalCount');
      return true;
    } catch (e) {
      print('❌ Error durante seeding: $e');
      rethrow;
    }
  }

  /// Crea tags para cada categoría principal
  Future<void> _seedCategoryTags() async {
    final categoryTags = <Tag>[];

    for (final category in defaultCategoriesHierarchy) {
      categoryTags.add(Tag(
        id: 0,
        canonicalName: category.id,
        displayName: category.name,
        tagType: 'THEME',
        description: category.description,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));

      // Crear tags para subcategorías
      if (category.subcategories != null) {
        for (final sub in category.subcategories!) {
          categoryTags.add(Tag(
            id: 0,
            canonicalName: sub.id,
            displayName: sub.name,
            tagType: 'THEME',
            description: sub.description,
            parentTagId: null, // Se establecerá después
            confidence: 0.95,
            createdAt: DateTime.now(),
          ));
        }
      }
    }

    await _tagDAO.insertBatch(categoryTags);
  }

  /// Crea tags específicos de deportes, jugadores y equipos
  Future<void> _seedSportsTags() async {
    final sportsTags = <Tag>[];

    // Deportes principales
    const sports = [
      ('football', 'Football', 'SPORT'),
      ('basketball', 'Basketball', 'SPORT'),
      ('tennis', 'Tennis', 'SPORT'),
      ('motorsport', 'Motorsport', 'SPORT'),
      ('formula-1', 'Formula 1', 'COMPETITION'),
      ('motogp', 'MotoGP', 'COMPETITION'),
      ('nfl', 'NFL', 'COMPETITION'),
      ('nba', 'NBA', 'COMPETITION'),
      ('premier-league', 'Premier League', 'COMPETITION'),
      ('champions-league', 'Champions League', 'COMPETITION'),
      ('mma', 'MMA / UFC', 'SPORT'),
      ('boxing', 'Boxing', 'SPORT'),
    ];

    for (final (id, name, type) in sports) {
      sportsTags.add(Tag(
        id: 0,
        canonicalName: id,
        displayName: name,
        tagType: type,
        description: null,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));
    }

    // Equipos principales
    const teams = [
      ('real-madrid', 'Real Madrid', 'TEAM', 'football'),
      ('barcelona', 'Barcelona', 'TEAM', 'football'),
      ('manchester-city', 'Manchester City', 'TEAM', 'football'),
      ('liverpool', 'Liverpool', 'TEAM', 'football'),
      ('manchester-united', 'Manchester United', 'TEAM', 'football'),
      ('psg', 'Paris Saint-Germain', 'TEAM', 'football'),
      ('bayern-munich', 'Bayern Munich', 'TEAM', 'football'),
      ('juventus', 'Juventus', 'TEAM', 'football'),
      ('inter-miami', 'Inter Miami', 'TEAM', 'football'),
      ('chelsea', 'Chelsea', 'TEAM', 'football'),
      ('arsenal', 'Arsenal', 'TEAM', 'football'),
      ('ferrari', 'Ferrari', 'TEAM', 'motorsport'),
      ('red-bull', 'Red Bull', 'TEAM', 'motorsport'),
      ('mercedes', 'Mercedes', 'TEAM', 'motorsport'),
      ('mclaren', 'McLaren', 'TEAM', 'motorsport'),
      ('lakers', 'Los Angeles Lakers', 'TEAM', 'basketball'),
      ('golden-state-warriors', 'Golden State Warriors', 'TEAM', 'basketball'),
    ];

    for (final (id, name, type, sport) in teams) {
      sportsTags.add(Tag(
        id: 0,
        canonicalName: id,
        displayName: name,
        tagType: type,
        description: null,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));
    }

    // Países (para contexto geográfico)
    const countries = [
      ('argentina', 'Argentina', 'COUNTRY'),
      ('spain', 'Spain', 'COUNTRY'),
      ('england', 'England', 'COUNTRY'),
      ('germany', 'Germany', 'COUNTRY'),
      ('france', 'France', 'COUNTRY'),
      ('italy', 'Italy', 'COUNTRY'),
      ('brazil', 'Brazil', 'COUNTRY'),
      ('united-states', 'United States', 'COUNTRY'),
      ('japan', 'Japan', 'COUNTRY'),
    ];

    for (final (id, name, type) in countries) {
      sportsTags.add(Tag(
        id: 0,
        canonicalName: id,
        displayName: name,
        tagType: type,
        description: null,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));
    }

    await _tagDAO.insertBatch(sportsTags);
  }

  /// Crea tags genéricos para estilos, colores y conceptos
  Future<void> _seedGenericTags() async {
    final genericTags = <Tag>[];

    // Estilos visuales
    const styles = [
      ('minimalist', 'Minimalist', 'STYLE'),
      ('cyberpunk', 'Cyberpunk', 'STYLE'),
      ('surreal', 'Surreal', 'STYLE'),
      ('abstract', 'Abstract', 'STYLE'),
      ('realistic', 'Realistic', 'STYLE'),
      ('digital-art', 'Digital Art', 'STYLE'),
      ('neon', 'Neon', 'STYLE'),
      ('dark', 'Dark', 'STYLE'),
      ('colorful', 'Colorful', 'STYLE'),
    ];

    for (final (id, name, type) in styles) {
      genericTags.add(Tag(
        id: 0,
        canonicalName: id,
        displayName: name,
        tagType: type,
        description: null,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));
    }

    // Géneros
    const genres = [
      ('sci-fi', 'Science Fiction', 'GENRE'),
      ('fantasy', 'Fantasy', 'GENRE'),
      ('action', 'Action', 'GENRE'),
      ('thriller', 'Thriller', 'GENRE'),
      ('horror', 'Horror', 'GENRE'),
      ('comedy', 'Comedy', 'GENRE'),
    ];

    for (final (id, name, type) in genres) {
      genericTags.add(Tag(
        id: 0,
        canonicalName: id,
        displayName: name,
        tagType: type,
        description: null,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));
    }

    // Conceptos generales
    const concepts = [
      ('nature', 'Nature', 'CONCEPT'),
      ('urban', 'Urban', 'CONCEPT'),
      ('landscape', 'Landscape', 'CONCEPT'),
      ('portrait', 'Portrait', 'CONCEPT'),
      ('animals', 'Animals', 'CONCEPT'),
      ('space', 'Space', 'CONCEPT'),
      ('technology', 'Technology', 'CONCEPT'),
      ('architecture', 'Architecture', 'CONCEPT'),
    ];

    for (final (id, name, type) in concepts) {
      genericTags.add(Tag(
        id: 0,
        canonicalName: id,
        displayName: name,
        tagType: type,
        description: null,
        parentTagId: null,
        confidence: 0.95,
        createdAt: DateTime.now(),
      ));
    }

    await _tagDAO.insertBatch(genericTags);
  }

  /// Crea relaciones entre tags
  Future<void> _seedRelations() async {
    // Esta es una versión simplificada
    // En producción, esto sería más extenso

    final db = await _appDatabase.database;

    // Obtener IDs de tags (es un poco ineficiente pero funcional para seeding)
    final footballTag = await _tagDAO.getByCanonicalName('football');
    final footballField = await _tagDAO.getByCanonicalName('futbol');
    final realMadridTag = await _tagDAO.getByCanonicalName('real-madrid');
    final spainTag = await _tagDAO.getByCanonicalName('spain');
    final premierLeagueTag = await _tagDAO.getByCanonicalName('premier-league');
    final formulaOneTag = await _tagDAO.getByCanonicalName('formula-1');
    final motorsportTag = await _tagDAO.getByCanonicalName('motorsport');
    final ferrariTag = await _tagDAO.getByCanonicalName('ferrari');

    final relations = <TagRelation>[];

    // Relaciones: Team → Sport
    if (realMadridTag != null && footballTag != null) {
      relations.add(TagRelation(
        id: 0,
        sourceTagId: realMadridTag.id,
        targetTagId: footballTag.id,
        relationType: 'plays_sport',
        createdAt: DateTime.now(),
      ));
    }

    // Relaciones: Team → Country
    if (realMadridTag != null && spainTag != null) {
      relations.add(TagRelation(
        id: 0,
        sourceTagId: realMadridTag.id,
        targetTagId: spainTag.id,
        relationType: 'based_in_country',
        createdAt: DateTime.now(),
      ));
    }

    // Relaciones: Sport → Hierarchy
    if (formulaOneTag != null && motorsportTag != null) {
      relations.add(TagRelation(
        id: 0,
        sourceTagId: formulaOneTag.id,
        targetTagId: motorsportTag.id,
        relationType: 'part_of_sport',
        createdAt: DateTime.now(),
      ));
    }

    // Relaciones: Team → Sport
    if (ferrariTag != null && motorsportTag != null) {
      relations.add(TagRelation(
        id: 0,
        sourceTagId: ferrariTag.id,
        targetTagId: motorsportTag.id,
        relationType: 'competes_in',
        createdAt: DateTime.now(),
      ));
    }

    if (relations.isNotEmpty) {
      await _relationDAO.insertBatch(relations);
    }
  }
}

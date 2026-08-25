/// Configuración de entidades específicas (jugadores, equipos, competiciones).
/// Permite búsquedas muy específicas sin modificar código.

/// Entidad deportiva (jugador, equipo, competición)
class SportEntity {
  const SportEntity({
    required this.id,
    required this.name,
    required this.sport,
    required this.category,
    this.aliases = const [],
    this.searchQueries = const [],
    this.country,
    this.year,
    this.description,
  });

  final String id;
  final String name;
  final String sport; // 'futbol', 'basketball', 'motor', etc.
  final String category; // 'player', 'team', 'competition'
  final List<String> aliases; // Nombres alternativos
  final List<String> searchQueries; // Queries específicas
  final String? country;
  final int? year;
  final String? description;

  /// Genera queries de búsqueda automáticamente si no se especifican
  List<String> getSearchQueries() {
    if (searchQueries.isNotEmpty) return searchQueries;

    final queries = <String>[];
    queries.add(name);
    queries.add('$name wallpaper');
    queries.add('$name 4K');

    if (category == 'player') {
      queries.add('$name portrait');
      queries.add('$name jersey');
    } else if (category == 'team') {
      queries.add('$name logo');
      queries.add('$name stadium');
    } else if (category == 'competition') {
      queries.add('$name trophy');
    }

    for (final alias in aliases) {
      queries.add(alias);
      queries.add('$alias wallpaper');
    }

    return queries;
  }
}

/// Configuración de jugadores de fútbol
const List<SportEntity> footballPlayers = [
  SportEntity(
    id: 'messi',
    name: 'Lionel Messi',
    sport: 'futbol',
    category: 'player',
    aliases: ['Leo Messi', 'Messi', 'Messi Argentina'],
    country: 'Argentina',
    description: 'Inter Miami CF, Argentina National Team',
  ),
  SportEntity(
    id: 'ronaldo',
    name: 'Cristiano Ronaldo',
    sport: 'futbol',
    category: 'player',
    aliases: ['CR7', 'Cristiano', 'Ronaldo'],
    country: 'Portugal',
    description: 'Al Nassr FC, Portugal National Team',
  ),
  SportEntity(
    id: 'mbappe',
    name: 'Kylian Mbappé',
    sport: 'futbol',
    category: 'player',
    aliases: ['Mbappe', 'Kylian', 'Mbappé'],
    country: 'France',
    description: 'Real Madrid, France National Team',
  ),
  SportEntity(
    id: 'haaland',
    name: 'Erling Haaland',
    sport: 'futbol',
    category: 'player',
    aliases: ['Haaland', 'Erling'],
    country: 'Norway',
    description: 'Manchester City, Norway National Team',
  ),
  SportEntity(
    id: 'neymar',
    name: 'Neymar Jr',
    sport: 'futbol',
    category: 'player',
    aliases: ['Neymar', 'Ney'],
    country: 'Brazil',
  ),
  SportEntity(
    id: 'lewandowski',
    name: 'Robert Lewandowski',
    sport: 'futbol',
    category: 'player',
    aliases: ['Lewandowski', 'Lewa'],
    country: 'Poland',
  ),
];

/// Configuración de equipos de fútbol
const List<SportEntity> footballTeams = [
  SportEntity(
    id: 'real_madrid',
    name: 'Real Madrid',
    sport: 'futbol',
    category: 'team',
    aliases: ['Real Madrid CF', 'Los Blancos', 'Madrid'],
    country: 'Spain',
  ),
  SportEntity(
    id: 'barcelona',
    name: 'FC Barcelona',
    sport: 'futbol',
    category: 'team',
    aliases: ['Barcelona', 'Barca', 'FCB'],
    country: 'Spain',
  ),
  SportEntity(
    id: 'manchester_city',
    name: 'Manchester City',
    sport: 'futbol',
    category: 'team',
    aliases: ['Man City', 'City'],
    country: 'England',
  ),
  SportEntity(
    id: 'liverpool',
    name: 'Liverpool FC',
    sport: 'futbol',
    category: 'team',
    aliases: ['Liverpool', 'LFC'],
    country: 'England',
  ),
  SportEntity(
    id: 'psg',
    name: 'Paris Saint-Germain',
    sport: 'futbol',
    category: 'team',
    aliases: ['PSG', 'Paris SG'],
    country: 'France',
  ),
  SportEntity(
    id: 'bayern',
    name: 'Bayern Munich',
    sport: 'futbol',
    category: 'team',
    aliases: ['Bayern', 'Bayern München', 'FCB'],
    country: 'Germany',
  ),
];

/// Competiciones de Fórmula 1
const List<SportEntity> f1Drivers = [
  SportEntity(
    id: 'max_verstappen',
    name: 'Max Verstappen',
    sport: 'motor',
    category: 'player',
    country: 'Netherlands',
    description: 'Red Bull Racing',
  ),
  SportEntity(
    id: 'lewis_hamilton',
    name: 'Lewis Hamilton',
    sport: 'motor',
    category: 'player',
    country: 'United Kingdom',
    description: 'Mercedes',
  ),
  SportEntity(
    id: 'charles_leclerc',
    name: 'Charles Leclerc',
    sport: 'motor',
    category: 'player',
    country: 'Monaco',
    description: 'Ferrari',
  ),
];

/// Mapa de todas las entidades por categoría
const Map<String, List<SportEntity>> entityDatabase = {
  'futbol_players': footballPlayers,
  'futbol_teams': footballTeams,
  'f1_drivers': f1Drivers,
};

/// Obtiene entidades por sport y categoría
List<SportEntity> getEntitiesBySport(String sport, String category) {
  final key = '${sport}_${category}s';
  return entityDatabase[key] ?? [];
}

/// Obtiene una entidad por ID
SportEntity? getEntityById(String id) {
  for (final list in entityDatabase.values) {
    final entity = list.cast<SportEntity?>().firstWhere(
          (e) => e?.id == id,
          orElse: () => null,
        );
    if (entity != null) return entity;
  }
  return null;
}

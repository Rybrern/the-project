import 'package:flutter/foundation.dart';

import '../providers/providers.dart';
import '../../models/wallpaper.dart';
import 'entity_config.dart';

/// Motor de descubrimiento específico por entidades.
/// Busca wallpapers de jugadores, equipos, competiciones específicos.
class EntityDiscoveryEngine {
  EntityDiscoveryEngine({required this.registry});

  final ProviderRegistry registry;

  /// Descubre wallpapers de un jugador específico
  Future<List<Wallpaper>> discoverPlayer(String playerId) async {
    final player = getEntityById(playerId);
    if (player == null) {
      debugPrint('EntityDiscoveryEngine: Player $playerId not found');
      return [];
    }

    debugPrint('EntityDiscoveryEngine: Discovering player: ${player.name}');
    return _searchEntity(player);
  }

  /// Descubre wallpapers de un equipo específico
  Future<List<Wallpaper>> discoverTeam(String teamId) async {
    final team = getEntityById(teamId);
    if (team == null) {
      debugPrint('EntityDiscoveryEngine: Team $teamId not found');
      return [];
    }

    debugPrint('EntityDiscoveryEngine: Discovering team: ${team.name}');
    return _searchEntity(team);
  }

  /// Descubre wallpapers de una competición
  Future<List<Wallpaper>> discoverCompetition(String competitionId) async {
    final competition = getEntityById(competitionId);
    if (competition == null) {
      debugPrint('EntityDiscoveryEngine: Competition $competitionId not found');
      return [];
    }

    debugPrint('EntityDiscoveryEngine: Discovering competition: ${competition.name}');
    return _searchEntity(competition);
  }

  /// Descubre wallpapers de todos los jugadores de un deporte
  Future<List<Wallpaper>> discoverAllPlayers(String sport, {int limitPerPlayer = 10}) async {
    final players = getEntitiesBySport(sport, 'player');
    debugPrint('EntityDiscoveryEngine: Discovering $sport players (${players.length} total)');

    final allWallpapers = <Wallpaper>[];
    final seenIds = <String>{};

    for (final player in players) {
      final wallpapers = await _searchEntity(player);
      final filtered = wallpapers.where((w) => seenIds.add(w.id)).take(limitPerPlayer);
      allWallpapers.addAll(filtered);
    }

    return allWallpapers;
  }

  /// Descubre wallpapers de todos los equipos de un deporte
  Future<List<Wallpaper>> discoverAllTeams(String sport, {int limitPerTeam = 10}) async {
    final teams = getEntitiesBySport(sport, 'team');
    debugPrint('EntityDiscoveryEngine: Discovering $sport teams (${teams.length} total)');

    final allWallpapers = <Wallpaper>[];
    final seenIds = <String>{};

    for (final team in teams) {
      final wallpapers = await _searchEntity(team);
      final filtered = wallpapers.where((w) => seenIds.add(w.id)).take(limitPerTeam);
      allWallpapers.addAll(filtered);
    }

    return allWallpapers;
  }

  /// Búsqueda interna para una entidad
  Future<List<Wallpaper>> _searchEntity(SportEntity entity) async {
    final queries = entity.getSearchQueries();
    final results = <Wallpaper>[];
    final seenUrls = <String>{};

    for (final query in queries) {
      try {
        final wallpapers = await _searchAllProviders(query);

        for (final wallpaper in wallpapers) {
          if (seenUrls.add(wallpaper.fullUrl)) {
            // Enriquece metadatos
            results.add(
              wallpaper.copyWith(
                primaryCategory: entity.sport,
                subcategory: entity.category,
                tags: [
                  ...?wallpaper.tags,
                  entity.name,
                  ...entity.aliases,
                ],
              ),
            );
          }
        }

        if (results.length >= 20) break; // Limita resultados
      } catch (e) {
        debugPrint('EntityDiscoveryEngine: Error searching for "$query": $e');
      }
    }

    return results;
  }

  /// Búsqueda en todos los providers habilitados
  Future<List<Wallpaper>> _searchAllProviders(String query) async {
    final providers = registry.getEnabledProviders();
    final results = <Wallpaper>[];

    for (final provider in providers) {
      try {
        final wallpapers = await provider.search(query, limit: 10);
        results.addAll(wallpapers);
      } catch (e) {
        debugPrint('EntityDiscoveryEngine: Error in ${provider.name}: $e');
      }
    }

    return results;
  }

  /// Obtiene estadísticas de entidades disponibles
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{
      'total_entities': 0,
      'by_sport': <String, int>{},
      'by_category': <String, int>{},
    };

    for (final entry in entityDatabase.entries) {
      stats['total_entities'] = (stats['total_entities'] as int) + entry.value.length;

      for (final entity in entry.value) {
        // Count by sport
        final sportCount = stats['by_sport'][entity.sport] ?? 0;
        stats['by_sport'][entity.sport] = sportCount + 1;

        // Count by category
        final categoryCount = stats['by_category'][entity.category] ?? 0;
        stats['by_category'][entity.category] = categoryCount + 1;
      }
    }

    return stats;
  }
}

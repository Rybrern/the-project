import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../models/category_hierarchy.dart';
import '../models/wallpaper.dart';
import 'wallpaper_service.dart';
import 'providers/providers.dart';
import 'discovery/discovery.dart';

/// Servicio unificado de wallpapers que combina el WallpaperService
/// existente con los nuevos Providers y DiscoveryEngine.
///
/// Proporciona compatibilidad hacia atrás con la UI existente mientras
/// expone nuevas capacidades de ingesta masiva.
class UnifiedWallpaperService implements WallpaperService {
  UnifiedWallpaperService({
    required String wallhavenApiKey,
    required String pixabayApiKey,
  }) {
    _registry.initializeDefaults(
      wallhavenApiKey: wallhavenApiKey,
      pixabayApiKey: pixabayApiKey,
    );
    _discoveryEngine = DiscoveryEngine(registry: _registry);
    _discoveryEngine.initialize(kWallpaperCategories.map((c) => _convertCategory(c)).toList());
  }

  final _registry = ProviderRegistry();
  late final DiscoveryEngine _discoveryEngine;

  /// Obtiene acceso directo al ProviderRegistry
  ProviderRegistry get registry => _registry;

  /// Obtiene acceso directo al DiscoveryEngine
  DiscoveryEngine get discoveryEngine => _discoveryEngine;

  @override
  Future<List<WallpaperCategory>> fetchCategories() async {
    return kWallpaperCategories;
  }

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final results = await Future.wait(
      kWallpaperCategories.map(_fetchForCategory),
    );
    return results.expand((wallpapers) => wallpapers).toList();
  }

  @override
  Stream<List<Wallpaper>> fetchWallpapersStream() {
    final controller = StreamController<List<Wallpaper>>();
    final accumulated = <Wallpaper>[];
    var remaining = kWallpaperCategories.length;

    for (final category in kWallpaperCategories) {
      _fetchForCategory(category).then((items) {
        accumulated.addAll(items);
        remaining--;
        if (controller.isClosed) return;
        controller.add(List.unmodifiable(accumulated));
        if (remaining == 0) controller.close();
      });
    }

    return controller.stream;
  }

  /// Busca wallpapers usando el nuevo discovery engine
  /// Compatible con categorías jerárquicas
  Future<List<Wallpaper>> discoverByCategory(String categoryId) async {
    return _discoveryEngine.discoverByCategory(categoryId);
  }

  /// Busca wallpapers en múltiples categorías (útil para ingesta masiva)
  Future<List<Wallpaper>> discoverByCategories(List<String> categoryIds) async {
    return _discoveryEngine.discoverByCategories(categoryIds);
  }

  /// Búsqueda manual personalizada
  Future<List<Wallpaper>> discoverByQuery(String query) async {
    return _discoveryEngine.search(query);
  }

  Future<List<Wallpaper>> _fetchForCategory(WallpaperCategory category) async {
    try {
      // Usa el nuevo discovery engine por debajo
      final wallpapers = await _discoveryEngine.search(category.query);

      // Mapea al modelo antiguo para compatibilidad
      return wallpapers.map((wp) {
        return wp.copyWith(
          category: category.id,
          forcePortraitCrop: category.forcePortraitCrop,
        );
      }).toList();
    } catch (error) {
      debugPrint('UnifiedWallpaperService: Failed to fetch "$category.query": $error');
      return const [];
    }
  }

  /// Convierte una categoría legacy a CategoryHierarchy
  static CategoryHierarchy _convertCategory(WallpaperCategory legacy) {
    return CategoryHierarchy(
      id: legacy.id,
      name: legacy.name,
      emoji: legacy.emoji,
      discoveryQueries: [legacy.query],
      forcePortraitCrop: legacy.forcePortraitCrop,
    );
  }
}

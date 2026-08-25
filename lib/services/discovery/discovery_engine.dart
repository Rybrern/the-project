import 'package:flutter/foundation.dart';

import '../../models/category_hierarchy.dart';
import '../../models/wallpaper.dart';
import '../providers/provider_registry.dart';
import 'query_generator.dart';

/// Motor de descubrimiento automatizado de wallpapers.
/// Genera queries a partir de la jerarquía de categorías y coordina
/// búsquedas en múltiples proveedores.
class DiscoveryEngine {
  DiscoveryEngine({
    required this.registry,
    this.maxConcurrentSearches = 3,
  });

  final ProviderRegistry registry;
  final int maxConcurrentSearches;

  late final QueryGenerator _queryGenerator;

  /// Inicializa el motor con las categorías disponibles
  void initialize(List<CategoryHierarchy> categories) {
    _queryGenerator = QueryGenerator(categories);
    debugPrint('DiscoveryEngine initialized with ${categories.length} root categories');
  }

  /// Ejecuta búsquedas para una categoría específica
  /// Retorna todos los wallpapers encontrados en todos los proveedores
  Future<List<Wallpaper>> discoverByCategory(
    String categoryId, {
    int limit = 100,
  }) async {
    final queries = _queryGenerator.getQueriesForCategory(categoryId);
    if (queries.isEmpty) {
      debugPrint('DiscoveryEngine: No queries found for category "$categoryId"');
      return [];
    }

    final results = <Wallpaper>[];
    for (final query in queries) {
      final wallpapers = await _searchAllProviders(query, limit: limit);
      results.addAll(wallpapers);

      // Para no sobrecargar las APIs, limita total de resultados
      if (results.length >= limit) {
        results.removeRange(limit, results.length);
        break;
      }
    }

    return results;
  }

  /// Ejecuta búsquedas para múltiples categorías
  /// Útil para actualización masiva
  Future<List<Wallpaper>> discoverByCategories(
    List<String> categoryIds, {
    int limitPerCategory = 50,
  }) async {
    final allResults = <Wallpaper>[];
    final seenIds = <String>{};

    for (final categoryId in categoryIds) {
      final wallpapers = await discoverByCategory(
        categoryId,
        limit: limitPerCategory,
      );

      // Evita duplicados por ID
      for (final wp in wallpapers) {
        if (seenIds.add(wp.id)) {
          allResults.add(wp);
        }
      }
    }

    return allResults;
  }

  /// Ejecuta búsqueda personalizada en todos los proveedores
  Future<List<Wallpaper>> search(String query, {int limit = 24}) async {
    return _searchAllProviders(query, limit: limit);
  }

  /// Ejecuta búsqueda en un proveedor específico
  Future<List<Wallpaper>> searchProvider(
    String providerName,
    String query, {
    int limit = 24,
  }) async {
    final provider = registry.getProvider(providerName);
    if (provider == null || !registry.isEnabled(providerName)) {
      debugPrint('DiscoveryEngine: Provider "$providerName" is not available');
      return [];
    }

    try {
      return await provider.search(query, limit: limit);
    } catch (e) {
      debugPrint('DiscoveryEngine: Error searching in "$providerName": $e');
      return [];
    }
  }

  /// Obtiene los queries sugeridos para una categoría
  List<String> getSuggestedQueries(String categoryId) {
    return _queryGenerator.getQueriesForCategory(categoryId);
  }

  /// Obtiene estadísticas de descubrimiento disponible
  Future<Map<String, dynamic>> getDiscoveryStats() async {
    final enabledProviders = registry.getEnabledProviders();
    final stats = <String, dynamic>{
      'total_queries': _queryGenerator.getTotalQueries(),
      'providers_enabled': enabledProviders.length,
      'providers': enabledProviders.map((p) => p.name).toList(),
    };

    return stats;
  }

  /// Búsqueda interna en todos los proveedores habilitados
  Future<List<Wallpaper>> _searchAllProviders(
    String query, {
    int limit = 24,
  }) async {
    final providers = registry.getEnabledProviders();
    if (providers.isEmpty) {
      debugPrint('DiscoveryEngine: No providers enabled');
      return [];
    }

    final results = <Wallpaper>[];
    final resultsPerProvider = (limit / providers.length).ceil();

    // Limita concurrencia
    for (var i = 0; i < providers.length; i += maxConcurrentSearches) {
      final batch = providers.skip(i).take(maxConcurrentSearches);
      final futures = batch.map(
        (p) => p.search(query, limit: resultsPerProvider).catchError(
              (e) {
                debugPrint('DiscoveryEngine: Error in provider "${p.name}": $e');
                return <Wallpaper>[];
              },
            ),
      );

      final batchResults = await Future.wait(futures);
      for (final providerResults in batchResults) {
        results.addAll(providerResults);
      }

      if (results.length >= limit) break;
    }

    // Limita al máximo solicitado
    if (results.length > limit) {
      results.removeRange(limit, results.length);
    }

    return results;
  }
}

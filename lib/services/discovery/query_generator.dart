import 'package:flutter/foundation.dart';

import '../../models/category_hierarchy.dart';

/// Genera automáticamente queries de búsqueda a partir de la jerarquía
/// de categorías. Permite evolucionar las búsquedas sin cambiar código.
class QueryGenerator {
  QueryGenerator(this.categories) {
    _buildQueryMap();
  }

  final List<CategoryHierarchy> categories;
  final Map<String, List<String>> _categoryQueries = {};

  /// Construye el mapa de queries a partir de la jerarquía
  void _buildQueryMap() {
    for (final category in categories) {
      _addCategory(category);
    }
  }

  /// Agrega una categoría y sus subcategorías de forma recursiva
  void _addCategory(CategoryHierarchy category, {String? parentPath}) {
    final path = parentPath != null ? '$parentPath/${category.id}' : category.id;

    // Queries de la categoría actual
    final queries = <String>[
      ...?category.discoveryQueries,
      category.name, // Siempre incluye el nombre
    ];

    _categoryQueries[path] = queries.toSet().toList(); // Remove duplicates

    // Procesa subcategorías
    if (category.subcategories != null) {
      for (final sub in category.subcategories!) {
        _addCategory(sub, parentPath: path);
      }
    }
  }

  /// Obtiene todos los queries para una categoría
  List<String> getQueriesForCategory(String categoryId) {
    // Busca en el mapa ambos: ID directo y rutas anidadas que terminen con el ID
    final queries = _categoryQueries[categoryId] ?? [];

    // También busca rutas que terminen con este ID
    for (final entry in _categoryQueries.entries) {
      if (entry.key.endsWith('/$categoryId') || entry.key.endsWith(categoryId)) {
        queries.addAll(entry.value);
      }
    }

    return queries.toSet().toList(); // Remove duplicates
  }

  /// Obtiene todos los queries registrados
  List<String> getAllQueries() {
    final allQueries = <String>{};
    for (final queries in _categoryQueries.values) {
      allQueries.addAll(queries);
    }
    return allQueries.toList();
  }

  /// Cuenta total de queries generados
  int getTotalQueries() {
    int total = 0;
    for (final queries in _categoryQueries.values) {
      total += queries.length;
    }
    return total;
  }

  /// Obtiene la ruta completa de una categoría
  String? getCategoryPath(String categoryId) {
    for (final path in _categoryQueries.keys) {
      if (path == categoryId || path.endsWith('/$categoryId')) {
        return path;
      }
    }
    return null;
  }

  /// Retorna estadísticas de generación
  Map<String, dynamic> getStatistics() {
    return {
      'total_categories': _categoryQueries.length,
      'total_queries': getTotalQueries(),
      'avg_queries_per_category':
          _categoryQueries.isEmpty ? 0 : getTotalQueries() / _categoryQueries.length,
    };
  }

  /// Debug: imprime el mapa de queries
  void printDebugInfo() {
    debugPrint('\n=== QueryGenerator Debug Info ===');
    for (final entry in _categoryQueries.entries) {
      debugPrint('${entry.key}: ${entry.value.length} queries');
      for (final query in entry.value) {
        debugPrint('  - $query');
      }
    }
    debugPrint('===================================\n');
  }
}

class CategoryHierarchy {
  const CategoryHierarchy({
    required this.id,
    required this.name,
    required this.emoji,
    this.description,
    this.subcategories,
    this.discoveryQueries,
    this.priority = 0,
    this.forcePortraitCrop = true,
  });

  final String id;
  final String name;
  final String emoji;
  final String? description;
  final List<CategoryHierarchy>? subcategories;
  final List<String>? discoveryQueries; // Búsquedas automáticas
  final int priority; // Para ordenamiento
  final bool forcePortraitCrop;

  /// Retorna true si esta categoría tiene subcategorías
  bool get hasSubcategories => subcategories?.isNotEmpty ?? false;

  /// Retorna la ruta completa: 'deportes/futbol/jugadores'
  String get fullPath => id;

  /// Retorna todos los queries de descubrimiento (incluyendo subcategorías)
  List<String> get allDiscoveryQueries {
    final queries = <String>{...?discoveryQueries};
    for (final sub in subcategories ?? []) {
      queries.addAll(sub.allDiscoveryQueries);
    }
    return queries.toList();
  }

  /// Busca una subcategoría por ID
  CategoryHierarchy? findSubcategory(String categoryId) {
    for (final sub in subcategories ?? []) {
      if (sub.id == categoryId) return sub;
      final found = sub.findSubcategory(categoryId);
      if (found != null) return found;
    }
    return null;
  }
}

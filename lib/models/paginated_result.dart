/// Resultado paginado genérico
class PaginatedResult<T> {
  PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    required this.totalCount,
  });

  /// Items en la página actual
  final List<T> items;

  /// Número de página actual (1-indexed)
  final int currentPage;

  /// Tamaño de la página
  final int pageSize;

  /// Total de items disponibles (si se conoce)
  final int totalCount;

  /// ¿Hay más páginas disponibles?
  bool get hasNextPage {
    final lastPageNum = (totalCount / pageSize).ceil();
    return currentPage < lastPageNum;
  }

  /// Número de la siguiente página
  int get nextPage => currentPage + 1;

  /// Número total de páginas
  int get totalPages => (totalCount / pageSize).ceil();

  /// ¿Es la primera página?
  bool get isFirstPage => currentPage == 1;

  /// ¿Es la última página?
  bool get isLastPage => !hasNextPage;

  /// Offset de items (para queries SQL OFFSET)
  int get offset => (currentPage - 1) * pageSize;
}

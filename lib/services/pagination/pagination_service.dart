import '../../database/daos/wallpaper_dao.dart';
import '../../models/wallpaper.dart';
import '../../models/paginated_result.dart';

/// Servicio que gestiona la paginación de wallpapers
/// Mantiene un buffer en memoria y carga nuevas páginas bajo demanda
class PaginationService {
  final WallpaperDAO _wallpaperDAO;

  PaginationService({required WallpaperDAO wallpaperDAO})
      : _wallpaperDAO = wallpaperDAO;

  static const int defaultPageSize = 20;
  static const int prefetchThreshold = 5; // items restantes para trigger prefetch

  /// Obtiene una página específica de wallpapers aceptados
  Future<PaginatedResult<Wallpaper>> getPage({
    required int pageNumber,
    int pageSize = defaultPageSize,
    String? categoryFilter,
  }) async {
    // Obtener todos los wallpapers aceptados (en producción, esto usaría offset/limit en DB)
    final allWallpapers = await _wallpaperDAO.getAllAccepted(limit: 10000);

    // Aplicar filtro de categoría si se especifica
    final filtered = categoryFilter == null
        ? allWallpapers
        : allWallpapers.where((w) => w.category == categoryFilter).toList();

    final totalCount = filtered.length;
    final offset = (pageNumber - 1) * pageSize;
    final pageItems = filtered.skip(offset).take(pageSize).toList();

    return PaginatedResult<Wallpaper>(
      items: pageItems,
      currentPage: pageNumber,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  /// Obtiene la siguiente página
  Future<PaginatedResult<Wallpaper>> getNextPage(
    PaginatedResult<Wallpaper> currentPage, {
    String? categoryFilter,
  }) async {
    if (!currentPage.hasNextPage) {
      return currentPage;
    }
    return getPage(
      pageNumber: currentPage.nextPage,
      pageSize: currentPage.pageSize,
      categoryFilter: categoryFilter,
    );
  }

  /// Obtiene las primeras N páginas de forma eager
  Future<List<PaginatedResult<Wallpaper>>> getFirstPages({
    required int numberOfPages,
    int pageSize = defaultPageSize,
    String? categoryFilter,
  }) async {
    final results = <PaginatedResult<Wallpaper>>[];
    for (int i = 1; i <= numberOfPages; i++) {
      results.add(await getPage(
        pageNumber: i,
        pageSize: pageSize,
        categoryFilter: categoryFilter,
      ));
    }
    return results;
  }
}

import '../../models/wallpaper.dart';

/// Interfaz base para todos los proveedores de wallpapers.
/// Cada fuente (Wallhaven, Pixabay, etc.) implementa esta interfaz.
abstract class WallpaperProvider {
  /// Nombre único del proveedor (ej: 'wallhaven', 'pixabay')
  String get name;

  /// Descripción del proveedor
  String get description;

  /// Prioridad para ordenamiento (mayor = más prioritario)
  int get priority => 0;

  /// Indica si está habilitado
  bool get isEnabled => true;

  /// Realiza una búsqueda simple
  Future<List<Wallpaper>> search(String query, {int limit = 24});

  /// Realiza búsqueda paginada
  Future<List<Wallpaper>> searchPaginated(
    String query, {
    int page = 1,
    int perPage = 24,
  });

  /// Busca por categoría con parámetros específicos
  Future<List<Wallpaper>> searchByCategory(
    String query, {
    String? aspectRatio,
    int limit = 24,
  });

  /// Obtiene trending/populares
  Future<List<Wallpaper>> getTrending({int limit = 24});

  /// Retorna todos los queries disponibles para este proveedor
  /// (usado por discovery engine)
  List<String> getAvailableQueries() => [];

  /// Valida la disponibilidad del proveedor (conectividad, API keys, etc.)
  Future<bool> validate();

  /// Retorna estadísticas del proveedor
  Future<Map<String, dynamic>> getStatistics() async => {};

  /// Reinicia estado interno (útil para resetear rate limiting, etc.)
  Future<void> reset() async {}
}

/// Respuesta estructurada de un proveedor
class ProviderSearchResult {
  const ProviderSearchResult({
    required this.provider,
    required this.wallpapers,
    required this.query,
    required this.totalAvailable,
    this.nextPageToken,
    this.error,
  });

  final String provider;
  final List<Wallpaper> wallpapers;
  final String query;
  final int totalAvailable;
  final String? nextPageToken;
  final String? error;

  bool get isSuccessful => error == null;
  bool get hasMore => nextPageToken != null;
}

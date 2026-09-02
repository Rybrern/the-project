import '../models/category.dart';
import '../models/wallpaper.dart';

/// Fuente de datos para los fondos de pantalla. Implementaciones:
/// - [MockWallpaperService]: datos de muestra con picsum.photos, sin red real.
/// - `WallhavenWallpaperService`: catálogo real vía la API de Wallhaven.
abstract class WallpaperService {
  Future<List<Wallpaper>> fetchWallpapers();

  /// Igual que [fetchWallpapers], pero emite la lista acumulada a medida que
  /// cada categoría va respondiendo, en vez de esperar a que todas terminen.
  /// Permite que la grilla se empiece a llenar apenas hay datos disponibles.
  Stream<List<Wallpaper>> fetchWallpapersStream();

  Future<List<WallpaperCategory>> fetchCategories();
}

const kWallpaperCategories = [
  WallpaperCategory(id: 'naturaleza', name: 'Naturaleza', emoji: '🌿', query: 'nature'),
  WallpaperCategory(id: 'abstracto', name: 'Abstracto', emoji: '🎨', query: 'abstract'),
  WallpaperCategory(id: 'espacio', name: 'Espacio', emoji: '🌌', query: 'space'),
  WallpaperCategory(id: 'minimalista', name: 'Minimalista', emoji: '⬛', query: 'minimal'),
  WallpaperCategory(id: 'arquitectura', name: 'Arquitectura', emoji: '🏙️', query: 'architecture'),
  WallpaperCategory(id: 'animales', name: 'Animales', emoji: '🐾', query: 'animals'),
  WallpaperCategory(id: 'oscuro', name: 'Oscuro', emoji: '🌑', query: 'dark'),
  WallpaperCategory(id: 'arte', name: 'Arte', emoji: '🖼️', query: 'art'),
  WallpaperCategory(
    id: 'tablets',
    name: 'Tablets',
    emoji: '💻',
    query: 'landscape',
    ratios: '16x9,16x10,4x3,3x2',
    forcePortraitCrop: false,
  ),
];

/// Implementación de muestra con imágenes de picsum.photos, para poder
/// levantar y navegar la app sin depender de una API key.
class MockWallpaperService implements WallpaperService {
  static const _heights = [520, 640, 760, 600, 700, 860, 560];
  static const _wallpapersPerCategory = 6;

  @override
  Future<List<WallpaperCategory>> fetchCategories() async => kWallpaperCategories;

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final wallpapers = <Wallpaper>[];
    var seed = 1;
    for (final category in kWallpaperCategories) {
      for (var i = 0; i < _wallpapersPerCategory; i++) {
        const width = 400;
        final height = _heights[seed % _heights.length];
        final fullHeight = (height / width * 1080).round();
        wallpapers.add(
          Wallpaper(
            id: '$seed',
            thumbnailUrl: 'https://picsum.photos/seed/$seed/$width/$height',
            fullUrl: 'https://picsum.photos/seed/$seed/1080/$fullHeight',
            author: 'Autor $seed',
            category: category.id,
            aspectRatio: width / height,
            forcePortraitCrop: category.forcePortraitCrop,
          ),
        );
        seed++;
      }
    }
    return wallpapers;
  }

  @override
  Stream<List<Wallpaper>> fetchWallpapersStream() => Stream.fromFuture(fetchWallpapers());
}

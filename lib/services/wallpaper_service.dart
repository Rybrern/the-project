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

/// Proporciones de pantalla de teléfono, en el formato que espera el
/// parámetro `ratios` de Wallhaven. Cubre desde el 16:9 clásico hasta los
/// paneles alargados actuales (21:9).
///
/// Sin este filtro la API devuelve casi puro fondo de escritorio 16:9: la
/// búsqueda "nature" sin `ratios` da resultados de 6000x3596 y 3840x2160,
/// que solo llegan a la pantalla del teléfono recortados y perdiendo
/// composición. Con el filtro hay ~349 fondos por categoría ya verticales.
const kPhoneRatios = '9x16,10x16,9x18,9x19,9x20,9x21';

const kWallpaperCategories = [
  WallpaperCategory(id: 'naturaleza', name: 'Naturaleza', emoji: '🌿', query: 'nature', ratios: kPhoneRatios),
  WallpaperCategory(id: 'abstracto', name: 'Abstracto', emoji: '🎨', query: 'abstract', ratios: kPhoneRatios),
  WallpaperCategory(id: 'espacio', name: 'Espacio', emoji: '🌌', query: 'space', ratios: kPhoneRatios),
  WallpaperCategory(id: 'minimalista', name: 'Minimalista', emoji: '⬛', query: 'minimal', ratios: kPhoneRatios),
  WallpaperCategory(id: 'arquitectura', name: 'Arquitectura', emoji: '🏙️', query: 'architecture', ratios: kPhoneRatios),
  WallpaperCategory(id: 'animales', name: 'Animales', emoji: '🐾', query: 'animals', ratios: kPhoneRatios),
  WallpaperCategory(id: 'oscuro', name: 'Oscuro', emoji: '🌑', query: 'dark', ratios: kPhoneRatios),
  WallpaperCategory(id: 'arte', name: 'Arte', emoji: '🖼️', query: 'art', ratios: kPhoneRatios),
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

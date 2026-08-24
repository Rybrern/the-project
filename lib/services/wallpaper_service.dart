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
  WallpaperCategory(
    id: 'naturaleza',
    name: 'Naturaleza',
    emoji: '🌿',
    query: 'nature',
  ),
  WallpaperCategory(
    id: 'abstracto',
    name: 'Abstracto',
    emoji: '🎨',
    query: 'abstract',
  ),
  WallpaperCategory(
    id: 'espacio',
    name: 'Espacio',
    emoji: '🌌',
    query: 'space',
  ),
  WallpaperCategory(
    id: 'minimalista',
    name: 'Minimalista',
    emoji: '⬛',
    query: 'minimal',
  ),
  WallpaperCategory(
    id: 'arquitectura',
    name: 'Arquitectura',
    emoji: '🏙️',
    query: 'architecture',
  ),
  WallpaperCategory(
    id: 'animales',
    name: 'Animales',
    emoji: '🐾',
    query: 'animals',
  ),
  WallpaperCategory(id: 'oscuro', name: 'Oscuro', emoji: '🌑', query: 'dark'),
  WallpaperCategory(id: 'arte', name: 'Arte', emoji: '🖼️', query: 'art'),
  // Categorías del criterio de contenido permitido que todavía no tenían
  // representación propia en el catálogo (antes solo estaban cubiertas de
  // forma indirecta por franquicias puntuales de juegos/películas).
  WallpaperCategory(
    id: 'paisajes-nocturnos',
    name: 'Paisajes nocturnos',
    emoji: '🌃',
    query: 'night landscape',
  ),
  WallpaperCategory(
    id: 'autos',
    name: 'Autos y motos',
    emoji: '🏎️',
    query: 'cars motorcycles',
  ),
  WallpaperCategory(
    id: 'deportes',
    name: 'Deportes',
    emoji: '⚽',
    query: 'sports',
  ),
  WallpaperCategory(
    id: 'celebridades',
    name: 'Celebridades',
    emoji: '🌟',
    query: 'celebrity portrait',
  ),
  WallpaperCategory(
    id: 'peliculas-series',
    name: 'Películas y series',
    emoji: '🎬',
    query: 'movie poster',
  ),
  WallpaperCategory(
    id: 'anime',
    name: 'Anime',
    emoji: '🎌',
    query: 'anime',
  ),
  WallpaperCategory(
    id: 'videojuegos',
    name: 'Videojuegos',
    emoji: '🎮',
    query: 'video games',
  ),
  WallpaperCategory(
    id: 'ciencia-ficcion',
    name: 'Ciencia ficción',
    emoji: '🚀',
    query: 'sci-fi',
  ),
  WallpaperCategory(
    id: 'fantasia',
    name: 'Fantasía',
    emoji: '🐉',
    query: 'fantasy art',
  ),
  WallpaperCategory(
    id: 'tecnologia',
    name: 'Tecnología',
    emoji: '🤖',
    query: 'technology',
  ),
  // Juegos y sagas populares. Cada entrada usa una búsqueda directa en
  // Wallhaven para que la sección se pueda ampliar sin cambiar la UI.
  WallpaperCategory(
    id: 'undertale',
    name: 'Undertale',
    emoji: '\u{1f9e1}',
    query: 'Undertale',
  ),
  WallpaperCategory(
    id: 'monster-hunter',
    name: 'Monster Hunter',
    emoji: '\u{1f409}',
    query: 'Monster Hunter',
  ),
  WallpaperCategory(
    id: 'hitman',
    name: 'Hitman',
    emoji: '\u{1f3af}',
    query: 'Hitman',
  ),
  WallpaperCategory(
    id: 'gta',
    name: 'Grand Theft Auto',
    emoji: '\u{1f697}',
    query: 'Grand Theft Auto',
  ),
  WallpaperCategory(
    id: 'minecraft',
    name: 'Minecraft',
    emoji: '\u{26cf}',
    query: 'Minecraft',
  ),
  WallpaperCategory(
    id: 'escape-from-tarkov',
    name: 'Escape from Tarkov',
    emoji: '\u{1f3af}',
    query: 'Escape from Tarkov',
  ),
  WallpaperCategory(
    id: 'uncharted',
    name: 'Uncharted',
    emoji: '\u{1f5fa}',
    query: 'Uncharted',
  ),
  WallpaperCategory(
    id: 'star-wars',
    name: 'Star Wars',
    emoji: '\u{2728}',
    query: 'Star Wars',
  ),
  WallpaperCategory(
    id: 'marvel',
    name: 'Marvel',
    emoji: '\u{1f9b8}',
    query: 'Marvel',
  ),
  WallpaperCategory(
    id: 'god-of-war',
    name: 'God of War',
    emoji: '\u{2694}',
    query: 'God of War',
  ),
  WallpaperCategory(
    id: 'the-witcher',
    name: 'The Witcher',
    emoji: '\u{1f43a}',
    query: 'The Witcher',
  ),
  WallpaperCategory(
    id: 'cyberpunk-2077',
    name: 'Cyberpunk 2077',
    emoji: '\u{1f916}',
    query: 'Cyberpunk 2077',
  ),
  WallpaperCategory(
    id: 'red-dead-redemption',
    name: 'Red Dead Redemption',
    emoji: '\u{1f920}',
    query: 'Red Dead Redemption',
  ),
  WallpaperCategory(
    id: 'the-last-of-us',
    name: 'The Last of Us',
    emoji: '\u{1f344}',
    query: 'The Last of Us',
  ),
  WallpaperCategory(
    id: 'elden-ring',
    name: 'Elden Ring',
    emoji: '\u{1f48d}',
    query: 'Elden Ring',
  ),
  WallpaperCategory(
    id: 'fallout',
    name: 'Fallout',
    emoji: '\u{2622}',
    query: 'Fallout',
  ),
  WallpaperCategory(
    id: 'assassins-creed',
    name: "Assassin's Creed",
    emoji: '\u{1f5e1}',
    query: "Assassin's Creed",
  ),
  WallpaperCategory(
    id: 'resident-evil',
    name: 'Resident Evil',
    emoji: '\u{1f9df}',
    query: 'Resident Evil',
  ),
  WallpaperCategory(
    id: 'the-legend-of-zelda',
    name: 'The Legend of Zelda',
    emoji: '\u{1f3f9}',
    query: 'The Legend of Zelda',
  ),
  WallpaperCategory(
    id: 'halo',
    name: 'Halo',
    emoji: '\u{1fa96}',
    query: 'Halo',
  ),
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
  Future<List<WallpaperCategory>> fetchCategories() async =>
      kWallpaperCategories;

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
  Stream<List<Wallpaper>> fetchWallpapersStream() =>
      Stream.fromFuture(fetchWallpapers());
}

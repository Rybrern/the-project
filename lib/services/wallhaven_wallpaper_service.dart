import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/category.dart';
import '../models/wallpaper.dart';
import 'utils/timeout_helper.dart';
import 'wallpaper_service.dart';

/// Catálogo real de fondos de pantalla vía la API de Wallhaven
/// (https://wallhaven.cc/help/api). Cada categoría de la app se resuelve
/// como una búsqueda por palabra clave contra la API.
class WallhavenWallpaperService implements WallpaperService {
  WallhavenWallpaperService({required this.apiKey});

  final String apiKey;

  static const _baseUrl = 'https://wallhaven.cc/api/v1/search';
  // 24 es el máximo que permite la API por página.
  static const _wallpapersPerCategory = 24;

  // El purity=100 de Wallhaven ("SFW") no alcanza solo: hay fan art de
  // personajes (sobre todo en categorías de juegos) que Wallhaven etiqueta
  // como SFW igual mostrando bastante piel. Estos términos negativos se
  // agregan a toda búsqueda para bajar ese riesgo — no lo eliminan del todo,
  // porque dependen de que la imagen esté etiquetada con alguno de estos
  // tags en Wallhaven.
  static const _safetyExclusions =
      '-nsfw -sexy -cleavage -bikini -lingerie -underwear -swimsuit -ecchi '
      '-ahegao -upskirt -pinup -thighs -boobs -butt -ass -bra -panties';

  @override
  Future<List<WallpaperCategory>> fetchCategories() async => kWallpaperCategories;

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    try {
      final results = await TimeoutHelper.withTimeout(
        Future.wait(kWallpaperCategories.map(_fetchForCategory)),
        timeout: const Duration(seconds: 60),
        operation: 'Load all wallpaper categories',
      );
      return results.expand((wallpapers) => wallpapers).toList();
    } catch (e) {
      debugPrint('WallhavenWallpaperService.fetchWallpapers error: $e');
      return [];
    }
  }

  @override
  Stream<List<Wallpaper>> fetchWallpapersStream() {
    final controller = StreamController<List<Wallpaper>>();
    final accumulated = <Wallpaper>[];
    var remaining = kWallpaperCategories.length;

    for (final category in kWallpaperCategories) {
      _fetchForCategory(category).then(
        (items) {
          if (controller.isClosed) return;
          accumulated.addAll(items);
          remaining--;
          controller.add(List.unmodifiable(accumulated));
          if (remaining == 0) controller.close();
        },
        onError: (error) {
          debugPrint('Error fetching ${category.query}: $error');
          remaining--;
          if (!controller.isClosed && remaining == 0) {
            controller.close();
          }
        },
      );
    }

    return controller.stream;
  }

  /// Si una categoría falla (red inestable, error puntual de la API), no
  /// tira abajo el resto del catálogo: esa categoría queda vacía y ya está.
  Future<List<Wallpaper>> _fetchForCategory(WallpaperCategory category) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'q': '${category.query} $_safetyExclusions',
        'categories': '100', // general only
        'purity': '100', // sfw only
        'sorting': 'random', // catálogo distinto en cada carga
        'per_page': '$_wallpapersPerCategory',
        if (category.ratios != null) 'ratios': category.ratios!,
      });

      final response = await TimeoutHelper.withTimeout(
        http.get(uri),
        timeout: const Duration(seconds: 15),
        operation: 'Wallhaven category: ${category.query}',
      );
      if (response.statusCode != 200) {
        throw Exception('Wallhaven devolvió ${response.statusCode} para "${category.query}"');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      return items.map((item) => _mapItem(item, category)).toList();
    } catch (error) {
      debugPrint('WallhavenWallpaperService: falló "${category.query}": $error');
      return const [];
    }
  }

  Wallpaper _mapItem(Map<String, dynamic> item, WallpaperCategory category) {
    final width = (item['dimension_x'] as num).toDouble();
    final height = (item['dimension_y'] as num).toDouble();
    final thumbs = item['thumbs'] as Map<String, dynamic>;

    return Wallpaper(
      id: item['id'] as String,
      thumbnailUrl: thumbs['large'] as String? ?? thumbs['small'] as String,
      fullUrl: item['path'] as String,
      author: 'Wallhaven',
      category: category.id,
      aspectRatio: width / height,
      forcePortraitCrop: category.forcePortraitCrop,
    );
  }
}

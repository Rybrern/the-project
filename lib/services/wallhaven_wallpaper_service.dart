import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/category.dart';
import '../models/wallpaper.dart';
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

  @override
  Future<List<WallpaperCategory>> fetchCategories() async => kWallpaperCategories;

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final results = await Future.wait(kWallpaperCategories.map(_fetchForCategory));
    return results.expand((wallpapers) => wallpapers).toList();
  }

  @override
  Stream<List<Wallpaper>> fetchWallpapersStream() {
    final controller = StreamController<List<Wallpaper>>();
    final accumulated = <Wallpaper>[];
    var remaining = kWallpaperCategories.length;

    for (final category in kWallpaperCategories) {
      _fetchForCategory(category).then((items) {
        accumulated.addAll(items);
        remaining--;
        if (controller.isClosed) return;
        controller.add(List.unmodifiable(accumulated));
        if (remaining == 0) controller.close();
      });
    }

    return controller.stream;
  }

  /// Si una categoría falla (red inestable, error puntual de la API), no
  /// tira abajo el resto del catálogo: esa categoría queda vacía y ya está.
  Future<List<Wallpaper>> _fetchForCategory(WallpaperCategory category) async {
    try {
      final queryParams = <String, String>{
        'q': category.query,
        'categories': '100', // general only
        'purity': '100', // sfw only
        'sorting': 'random', // catálogo distinto en cada carga
        'per_page': '$_wallpapersPerCategory',
        if (category.ratios != null) 'ratios': category.ratios!,
        if (apiKey.isNotEmpty) 'apikey': apiKey,
      };
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Wallhaven devolvió ${response.statusCode} para "${category.query}"');
      }
      // Validación básica de tamaño para evitar OOM (máx 2MB de JSON)
      if (response.bodyBytes.length > 2 * 1024 * 1024) {
        throw Exception('Respuesta Wallhaven demasiado grande');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      return items.map((item) => _mapItem(item, category)).toList();
    } on TimeoutException {
      debugPrint('WallhavenWallpaperService: timeout para "${category.query}"');
      return const [];
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

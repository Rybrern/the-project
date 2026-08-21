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
  static const _wallpapersPerCategory = 12;

  /// Proporciones típicas de pantallas de celular (retrato). Filtrar por esto
  /// en la API evita traer fondos pensados para monitores horizontales.
  static const _portraitRatios = '9x16,9x18,9x19,9x20,10x16';

  @override
  Future<List<WallpaperCategory>> fetchCategories() async => kWallpaperCategories;

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final results = await Future.wait(kWallpaperCategories.map(_fetchForCategory));
    return results.expand((wallpapers) => wallpapers).toList();
  }

  /// Si una categoría falla (red inestable, error puntual de la API), no
  /// tira abajo el resto del catálogo: esa categoría queda vacía y ya está.
  Future<List<Wallpaper>> _fetchForCategory(WallpaperCategory category) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'q': category.query,
        'categories': '100', // general only
        'purity': '100', // sfw only
        'ratios': _portraitRatios,
        'sorting': 'toplist',
        'order': 'desc',
        'per_page': '$_wallpapersPerCategory',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Wallhaven devolvió ${response.statusCode} para "${category.query}"');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      return items.map((item) => _mapItem(item, category.id)).toList();
    } catch (error) {
      debugPrint('WallhavenWallpaperService: falló "${category.query}": $error');
      return const [];
    }
  }

  Wallpaper _mapItem(Map<String, dynamic> item, String categoryId) {
    final width = (item['dimension_x'] as num).toDouble();
    final height = (item['dimension_y'] as num).toDouble();
    final thumbs = item['thumbs'] as Map<String, dynamic>;

    return Wallpaper(
      id: item['id'] as String,
      thumbnailUrl: thumbs['large'] as String? ?? thumbs['small'] as String,
      fullUrl: item['path'] as String,
      author: 'Wallhaven',
      category: categoryId,
      aspectRatio: width / height,
    );
  }
}

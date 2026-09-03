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

  /// Resolución mínima exigida a la API, orientada según la categoría.
  ///
  /// `atleast` compara ancho y alto por separado, así que el valor tiene que
  /// seguir la orientación buscada: pedir `1920x1080` en una categoría
  /// vertical descarta un fondo de 1080x1920 por "poco ancho", que es
  /// justamente la forma de pantalla que queremos.
  String _minResolutionFor(WallpaperCategory category) =>
      category.forcePortraitCrop ? '1080x1920' : '1920x1080';

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
        // server-side filtro HD mínimo (ahorra ancho de banda)
        'atleast': _minResolutionFor(category),
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
      return items
          .map((item) => _mapItem(item, category))
          .whereType<Wallpaper>()
          .toList();
    } on TimeoutException {
      debugPrint('WallhavenWallpaperService: timeout para "${category.query}"');
      return const [];
    } catch (error) {
      debugPrint('WallhavenWallpaperService: falló "${category.query}": $error');
      return const [];
    }
  }

  /// Busca por tag/palabra clave libre contra la API de Wallhaven (a
  /// diferencia de [fetchWallpapers], que solo itera [kWallpaperCategories]).
  /// A diferencia de [_fetchForCategory], un error acá se relanza en vez de
  /// devolver `[]`: el usuario está esperando activamente el resultado de
  /// esta búsqueda puntual, así que la pantalla debe poder mostrar un
  /// estado de error real en vez de un silencioso "sin resultados".
  Future<List<Wallpaper>> searchByTag(String query, {int page = 1}) async {
    final searchCategory = WallpaperCategory(
      id: 'busqueda',
      name: 'Búsqueda',
      emoji: '🔍',
      query: query,
    );
    final queryParams = <String, String>{
      'q': query,
      'categories': '100',
      'purity': '100',
      'sorting': 'relevance',
      'per_page': '$_wallpapersPerCategory',
      'page': '$page',
      // Piso neutro respecto de la orientación: pedir 1920x1080 acá dejaba
      // fuera cualquier resultado vertical, aunque el usuario busque justo
      // eso. El mínimo real (lado corto >=1080, largo >=1920) lo aplica
      // _isHighQuality, que sí es agnóstico a la orientación.
      'atleast': '1080x1080',
      if (apiKey.isNotEmpty) 'apikey': apiKey,
    };
    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Wallhaven devolvió ${response.statusCode} para "$query"');
    }
    if (response.bodyBytes.length > 2 * 1024 * 1024) {
      throw Exception('Respuesta Wallhaven demasiado grande');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    return items
        .map((item) => _mapItem(item, searchCategory))
        .whereType<Wallpaper>()
        .toList();
  }

  // Filtro de calidad: rechaza fondos que se verán pixelados en pantalla completa.
  // - Rechaza GIF/animados (baja calidad Giphy, artefactos)
  // - Rechaza resoluciones < 1080p en lado corto (se verá borroso al estirar)
  bool _isHighQuality(Map<String, dynamic> item) {
    final fileType = item['file_type'] as String?;
    if (fileType != null && fileType.toLowerCase().contains('gif')) return false;
    final w = item['dimension_x'] as num?;
    final h = item['dimension_y'] as num?;
    if (w == null || h == null) return false;
    final shortSide = w.toDouble() < h.toDouble() ? w.toDouble() : h.toDouble();
    final longSide = w.toDouble() > h.toDouble() ? w.toDouble() : h.toDouble();
    // Mínimo HD: lado corto >=1080, largo >=1920 (~2MP). Ajustable via atleast en query.
    if (shortSide < 1080 || longSide < 1920) return false;
    // Opcional: filtrar archivos muy pequeños (<300KB suele ser thumbnail upscaleado)
    final fileSize = item['file_size'] as num?;
    if (fileSize != null && fileSize < 300 * 1024) return false;
    return true;
  }

  double _qualityScore(num w, num h) {
    final pixels = w.toDouble() * h.toDouble();
    if (pixels >= 3840 * 2160) return 1.0; // 4K
    if (pixels >= 2560 * 1440) return 0.9; // QHD
    if (pixels >= 1920 * 1080) return 0.8; // FHD
    if (pixels >= 1280 * 720) return 0.5;
    return 0.2;
  }

  Wallpaper? _mapItem(Map<String, dynamic> item, WallpaperCategory category) {
    if (!_isHighQuality(item)) return null;
    final width = (item['dimension_x'] as num).toDouble();
    final height = (item['dimension_y'] as num).toDouble();
    final thumbs = item['thumbs'] as Map<String, dynamic>;
    // Tags oficiales de Wallhaven
    final tags = (item['tags'] as List<dynamic>?)
        ?.map((t) => (t as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .toList();

    return Wallpaper(
      id: item['id'] as String,
      thumbnailUrl: thumbs['large'] as String? ?? thumbs['small'] as String,
      fullUrl: item['path'] as String,
      author: 'Wallhaven',
      category: category.id,
      aspectRatio: width / height,
      forcePortraitCrop: category.forcePortraitCrop,
      source: 'wallhaven',
      sourceId: item['id'] as String,
      originalUrl: 'https://wallhaven.cc/w/${item['id']}',
      tags: tags,
      width: width.toInt(),
      height: height.toInt(),
      fileSize: (item['file_size'] as num?)?.toInt(),
      fileType: item['file_type'] as String?,
      qualityScore: _qualityScore(width, height),
      previewUrl: thumbs['large'] as String?,
    );
  }
}

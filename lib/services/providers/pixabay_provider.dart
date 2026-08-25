import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/animated_wallpaper.dart';
import '../../models/wallpaper.dart';
import '../../config/media_api_config.dart';
import '../../utils/wallpaper_content_filter.dart';
import 'provider_base.dart';

class PixabayProvider implements WallpaperProvider {
  PixabayProvider({this.apiKey = pixabayApiKey});

  final String apiKey;
  static const _baseUrl = 'https://pixabay.com/api/';
  static const _videoBaseUrl = 'https://pixabay.com/api/videos/';
  static const _perPage = 30;

  @override
  String get name => 'pixabay';

  @override
  String get description => 'Pixabay - Free images and videos';

  @override
  int get priority => 5;

  @override
  bool get isEnabled => apiKey.isNotEmpty;

  /// Busca imágenes estáticas en Pixabay
  /// FIX: Removido requisito 1920×1080 que era muy estricto y descartaba muchas imágenes válidas.
  /// Ahora usa mínimo 800×600 para permitir más resultados.
  /// La validación de contenido se hace después en _mapImageToWallpaper.
  Future<List<Wallpaper>> searchImages(
    String query, {
    int limit = 24,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'key': apiKey,
        'q': query,
        'safesearch': 'true',
        'per_page': '$limit',
        'image_type': 'photo',
        'min_width': '800',
        'min_height': '600',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Pixabay returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = (body['hits'] as List<dynamic>).cast<Map<String, dynamic>>();

      // FIX: Cambiar a usar map() en lugar de whereType() para evitar descartar
      // imágenes válidas. Si _mapImageToWallpaper retorna null, se filtra aquí.
      return hits
          .map(_mapImageToWallpaper)
          .where((wp) => wp != null)
          .cast<Wallpaper>()
          .toList();
    } catch (error) {
      debugPrint('PixabayProvider.searchImages error: $error');
      return [];
    }
  }

  /// Busca videos en Pixabay
  Future<List<AnimatedWallpaper>> searchVideos(
    String query, {
    int limit = 24,
  }) async {
    try {
      final uri = Uri.parse(_videoBaseUrl).replace(queryParameters: {
        'key': apiKey,
        'q': query,
        'safesearch': 'true',
        'per_page': '$limit',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Pixabay returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = (body['hits'] as List<dynamic>).cast<Map<String, dynamic>>();

      return hits.map(_mapVideoToAnimatedWallpaper).whereType<AnimatedWallpaper>().toList();
    } catch (error) {
      debugPrint('PixabayProvider.searchVideos error: $error');
      return [];
    }
  }

  @override
  Future<List<Wallpaper>> search(String query, {int limit = 24}) async {
    return searchImages(query, limit: limit);
  }

  @override
  Future<List<Wallpaper>> searchPaginated(
    String query, {
    int page = 1,
    int perPage = 24,
  }) async {
    // Pixabay no soporta paginación tradicional, usa `per_page` directamente
    // Para obtener "más resultados" se realiza el offset en la aplicación
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'key': apiKey,
        'q': query,
        'safesearch': 'true',
        'per_page': '$perPage',
        'image_type': 'photo',
        'min_width': '800',
        'min_height': '600',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Pixabay returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = (body['hits'] as List<dynamic>).cast<Map<String, dynamic>>();

      return hits
          .map(_mapImageToWallpaper)
          .where((wp) => wp != null)
          .cast<Wallpaper>()
          .toList();
    } catch (error) {
      debugPrint('PixabayProvider.searchPaginated error: $error');
      return [];
    }
  }

  @override
  Future<List<Wallpaper>> searchByCategory(
    String query, {
    String? aspectRatio,
    int limit = 24,
  }) async {
    // Pixabay no tiene parámetros de aspect ratio específicos
    return searchImages(query, limit: limit);
  }

  @override
  Future<List<Wallpaper>> getTrending({int limit = 24}) async {
    return searchImages('popular', limit: limit);
  }

  @override
  Future<bool> validate() async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'key': apiKey,
        'per_page': '1',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return {
      'provider': name,
      'available': await validate(),
    };
  }

  @override
  List<String> getAvailableQueries() => [
    'landscape', 'nature', 'space', 'abstract', 'architecture',
    'animals', 'city', 'art', 'car', 'motorcycle', 'sports',
    'person', 'movie', 'anime', 'game', 'technology',
  ];

  @override
  Future<void> reset() async {}

  Wallpaper? _mapImageToWallpaper(Map<String, dynamic> hit) {
    final width = hit['imageWidth'] as int;
    final height = hit['imageHeight'] as int;
    final tags = (hit['tags'] as String?);

    if (!WallpaperContentFilter.isAppropriateWallpaper(
      text: tags,
      width: width,
      height: height,
    )) {
      return null;
    }

    return Wallpaper(
      id: 'pixabay_${hit['id']}',
      thumbnailUrl: hit['previewURL'] as String,
      fullUrl: hit['largeImageURL'] as String? ?? hit['webformatURL'] as String,
      author: hit['user'] as String? ?? 'Pixabay',
      category: 'general',
      aspectRatio: width / height,
      source: 'pixabay',
      sourceId: (hit['id'] as int).toString(),
      originalUrl: hit['pageURL'] as String?,
      tags: tags?.split(','),
    );
  }

  AnimatedWallpaper? _mapVideoToAnimatedWallpaper(Map<String, dynamic> hit) {
    final videos = hit['videos'] as Map<String, dynamic>;
    final tier = _pickVideoTier(videos);

    if (tier == null) return null;

    final width = tier['width'] as int;
    final height = tier['height'] as int;
    final tags = hit['tags'] as String?;

    if (!WallpaperContentFilter.isAppropriateWallpaper(
      text: tags,
      width: width,
      height: height,
    )) {
      return null;
    }

    return AnimatedWallpaper(
      id: 'pixabay_video_${hit['id']}',
      previewImageUrl: tier['thumbnail'] as String,
      videoUrl: tier['url'] as String,
      width: width,
      height: height,
    );
  }

  /// Selecciona el mejor tier disponible para un video de Pixabay.
  /// Siempre retorna un tier válido o null solo si el video está completamente vacío.
  /// IMPORTANTE: Nunca descarta un video solo porque no tenga el tier preferido.
  Map<String, dynamic>? _pickVideoTier(Map<String, dynamic> videos) {
    const preferredOrder = ['small', 'tiny', 'medium', 'large'];

    // Busca en orden de preferencia
    for (final tierName in preferredOrder) {
      final tier = videos[tierName];
      if (tier is Map<String, dynamic>) return tier;
    }

    // FALLBACK: Si ninguno preferido existe, usa el primero disponible
    for (final entry in videos.entries) {
      if (entry.value is Map<String, dynamic>) {
        debugPrint('PixabayProvider: Video no tiene tier preferido, usando fallback: ${entry.key}');
        return entry.value as Map<String, dynamic>;
      }
    }

    return null;
  }
}

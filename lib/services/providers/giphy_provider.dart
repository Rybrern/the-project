import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/animated_wallpaper.dart';
import '../../models/wallpaper.dart';
import '../../config/media_api_config.dart';
import '../../utils/wallpaper_content_filter.dart';
import 'provider_base.dart';

/// Adapter para GIPHY que proporciona GIFs animados como AnimatedWallpaper.
/// Implementa rate limiting (43 requests/hour), filtrado de memes y NSFW,
/// y soporte para múltiples resoluciones.
///
/// GIPHY API: https://api.giphy.com/v1/gifs/search
/// Rate limit: 43 requests/hour para free tier
class GiphyProvider implements WallpaperProvider {
  GiphyProvider({
    this.apiKey = giphyApiKey,
    this.rateLimitPerHour = 43,
  }) {
    _rateLimiter = _RateLimiter(rateLimitPerHour);
  }

  final String apiKey;
  final int rateLimitPerHour;

  late _RateLimiter _rateLimiter;

  static const _baseUrl = 'https://api.giphy.com/v1/gifs';
  static const _requestDelayMs = 100; // Delay entre requests para rate limiting

  @override
  String get name => 'giphy';

  @override
  String get description => 'GIPHY - Trending and search GIF animations';

  @override
  int get priority => 4;

  @override
  bool get isEnabled => apiKey.isNotEmpty;

  /// Categorías primarias inferidas por palabras clave
  static const _categoryKeywords = <String, String>{
    'nature': 'naturaleza',
    'landscape': 'paisajes',
    'space': 'espacio',
    'universe': 'espacio',
    'galaxy': 'espacio',
    'animal': 'animales',
    'water': 'agua',
    'wave': 'agua',
    'fire': 'fuego',
    'abstract': 'abstracto',
    'motion': 'movimiento',
    'gradient': 'gradiente',
    'aurora': 'aurora',
    'city': 'ciudad',
    'urban': 'ciudad',
  };

  /// Busca videos animados en GIPHY
  Future<List<AnimatedWallpaper>> searchVideos(
    String query, {
    int limit = 24,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'api_key': apiKey,
        'q': query,
        'limit': '$limit',
        'offset': '0',
        'rating': 'g,pg',
        'lang': 'en',
      });

      final response = await _makeRateLimitedRequest(uri);
      if (response == null) {
        debugPrint('GiphyProvider: Rate limited, returning empty list');
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception('GIPHY returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      return data
          .map(_mapGifToAnimatedWallpaper)
          .where((wp) => wp != null)
          .cast<AnimatedWallpaper>()
          .toList();
    } catch (error) {
      debugPrint('GiphyProvider.searchVideos error: $error');
      return [];
    }
  }

  /// Obtiene trending GIFs de GIPHY
  Future<List<AnimatedWallpaper>> getTrendingVideos({int limit = 24}) async {
    try {
      final uri = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
        'api_key': apiKey,
        'limit': '$limit',
        'offset': '0',
        'rating': 'g,pg',
      });

      final response = await _makeRateLimitedRequest(uri);
      if (response == null) {
        debugPrint('GiphyProvider: Rate limited, returning empty list');
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception('GIPHY returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      return data
          .map((gif) => _mapGifToAnimatedWallpaper(gif, isTrending: true))
          .where((wp) => wp != null)
          .cast<AnimatedWallpaper>()
          .toList();
    } catch (error) {
      debugPrint('GiphyProvider.getTrendingVideos error: $error');
      return [];
    }
  }

  @override
  Future<List<Wallpaper>> search(String query, {int limit = 24}) async {
    // Para mantener compatibilidad con WallpaperProvider, devolvemos empty
    // Los consumidores deben usar searchVideos() directamente
    return [];
  }

  @override
  Future<List<Wallpaper>> searchPaginated(
    String query, {
    int page = 1,
    int perPage = 24,
  }) async {
    // Para mantener compatibilidad con WallpaperProvider, devolvemos empty
    return [];
  }

  @override
  Future<List<Wallpaper>> searchByCategory(
    String query, {
    String? aspectRatio,
    int limit = 24,
  }) async {
    // Para mantener compatibilidad con WallpaperProvider, devolvemos empty
    return [];
  }

  @override
  Future<List<Wallpaper>> getTrending({int limit = 24}) async {
    // Para mantener compatibilidad con WallpaperProvider, devolvemos empty
    return [];
  }

  @override
  Future<bool> validate() async {
    try {
      final uri = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
        'api_key': apiKey,
        'limit': '1',
      });

      final response = await _makeRateLimitedRequest(uri)
          .timeout(const Duration(seconds: 5));
      return response != null && response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return {
      'provider': name,
      'available': await validate(),
      'rateLimitPerHour': rateLimitPerHour,
      'requestsRemaining': _rateLimiter.requestsRemaining,
    };
  }

  @override
  List<String> getAvailableQueries() => [
    'nature', 'space', 'abstract', 'animals', 'water',
    'fire', 'landscape', 'aurora', 'motion', 'gradient',
    'city', 'ocean', 'mountains', 'forest', 'sky',
    'clouds', 'sunset', 'stars', 'waves', 'rain',
  ];

  @override
  Future<void> reset() async {
    _rateLimiter.reset();
  }

  /// Realiza una request con rate limiting
  Future<http.Response?> _makeRateLimitedRequest(Uri uri) async {
    if (!_rateLimiter.canMakeRequest()) {
      debugPrint('GiphyProvider: Rate limit exceeded');
      return null;
    }

    _rateLimiter.recordRequest();

    // Espera el delay para no sobrecargar
    await Future<void>.delayed(const Duration(milliseconds: _requestDelayMs));

    return http.get(uri);
  }

  /// Mapea respuesta de GIPHY a AnimatedWallpaper
  AnimatedWallpaper? _mapGifToAnimatedWallpaper(
    Map<String, dynamic> gif, {
    bool isTrending = false,
  }) {
    try {
      final id = gif['id'] as String?;
      final title = gif['title'] as String? ?? 'GIPHY GIF';
      final images = gif['images'] as Map<String, dynamic>?;
      final rating = gif['rating'] as String? ?? 'g';
      final tags = (gif['tags'] as List<dynamic>?)?.cast<String>() ?? [];

      if (id == null || images == null || images.isEmpty) {
        return null;
      }

      // Filtrado de NSFW por rating
      final nsfwScore = _calculateNsfwScore(rating);
      if (nsfwScore > 0.5) {
        // Considerar pg-13 y r como NSFW alto
        return null;
      }

      // Obtener URLs de video/imagen
      final videoUrl = _extractVideoUrl(images);
      final previewUrl = _extractPreviewUrl(images);

      if (videoUrl == null || previewUrl == null) {
        return null;
      }

      // Obtener dimensiones
      final dimensions = _extractDimensions(images);
      if (dimensions == null) {
        return null;
      }

      // Validar contenido apropiado (resolver memes)
      if (!WallpaperContentFilter.isAppropriateWallpaper(
        text: '${title.toLowerCase()} ${tags.join(' ')}',
        width: dimensions['width']!,
        height: dimensions['height']!,
      )) {
        return null;
      }

      // Agregar tags de trending si aplica
      final finalTags = <String>[...tags];
      if (isTrending) {
        finalTags.add('giphy-trending');
      }

      // Inferir categoría
      final category = _inferCategory(title, tags);

      return AnimatedWallpaper(
        id: 'giphy_$id',
        previewImageUrl: previewUrl,
        videoUrl: videoUrl,
        width: dimensions['width']!,
        height: dimensions['height']!,
        source: 'giphy',
        sourceId: id,
        tags: finalTags,
        nsfwScore: nsfwScore,
        qualityScore: _calculateQualityScore(dimensions['width']!, dimensions['height']!),
        primaryCategory: category,
        processingStatus: 'accepted',
      );
    } catch (error) {
      debugPrint('GiphyProvider._mapGifToAnimatedWallpaper error: $error');
      return null;
    }
  }

  /// Extrae URL de video MP4 o GIF, priorizando MP4
  String? _extractVideoUrl(Map<String, dynamic> images) {
    // Preferencia: fixed_height_small.mp4 > fixed_height.mp4 > original.mp4 > .gif
    const preferredOrder = [
      'fixed_height_small',
      'fixed_height',
      'original',
    ];

    for (final key in preferredOrder) {
      final item = images[key];
      if (item is Map<String, dynamic>) {
        final mp4 = item['mp4'] as String?;
        if (mp4 != null && mp4.isNotEmpty) {
          return mp4;
        }
      }
    }

    // Fallback a GIF
    for (final key in preferredOrder) {
      final item = images[key];
      if (item is Map<String, dynamic>) {
        final url = item['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
    }

    return null;
  }

  /// Extrae URL de preview (imagen estática)
  String? _extractPreviewUrl(Map<String, dynamic> images) {
    // Preferencia: fixed_height > fixed_width > original > downsized
    const preferredOrder = [
      'fixed_height',
      'fixed_width',
      'original',
      'downsized',
    ];

    for (final key in preferredOrder) {
      final item = images[key];
      if (item is Map<String, dynamic>) {
        final url = item['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
    }

    return null;
  }

  /// Extrae dimensiones del GIF (width y height)
  /// Intenta múltiples fuentes para obtener el mejor tamaño disponible
  Map<String, int>? _extractDimensions(Map<String, dynamic> images) {
    // Preferencia por resoluciones más altas
    const preferredOrder = [
      'original',
      'fixed_height',
      'fixed_width',
      'fixed_height_small',
      'downsized',
    ];

    for (final key in preferredOrder) {
      final item = images[key];
      if (item is Map<String, dynamic>) {
        final width = _parseIntValue(item['width']);
        final height = _parseIntValue(item['height']);

        if (width != null && height != null && width > 0 && height > 0) {
          return {'width': width, 'height': height};
        }
      }
    }

    return null;
  }

  /// Convierte valor a int (puede ser string o int en la respuesta)
  int? _parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Calcula puntuación NSFW basada en rating
  /// g: 0.0, pg: 0.2, pg-13: 0.3, r: 0.8
  double _calculateNsfwScore(String rating) {
    switch (rating.toLowerCase()) {
      case 'g':
        return 0.0;
      case 'pg':
        return 0.2;
      case 'pg-13':
        return 0.3;
      case 'r':
        return 0.8;
      default:
        return 0.1;
    }
  }

  /// Calcula puntuación de calidad basada en resolución
  double _calculateQualityScore(int width, int height) {
    // Basado en resolución: 360x360 = 0.2, 800x600 = 0.7, 1920x1080 = 1.0
    final pixels = width * height;
    if (pixels < 130000) return 0.2; // < 360x360
    if (pixels < 480000) return 0.5; // < 800x600
    if (pixels < 2073600) return 0.8; // < 1920x1080
    return 1.0;
  }

  /// Infiere categoría primaria del título y tags
  String _inferCategory(String title, List<String> tags) {
    final combinedText = '${title.toLowerCase()} ${tags.join(' ').toLowerCase()}';

    for (final entry in _categoryKeywords.entries) {
      if (combinedText.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'general';
  }
}

/// Rate limiter para controlar requests según límite por hora
class _RateLimiter {
  _RateLimiter(this.maxRequestsPerHour)
      : _requestTimestamps = <int>[];

  final int maxRequestsPerHour;
  final List<int> _requestTimestamps;

  int get requestsRemaining {
    _cleanOldTimestamps();
    return maxRequestsPerHour - _requestTimestamps.length;
  }

  bool canMakeRequest() {
    _cleanOldTimestamps();
    return _requestTimestamps.length < maxRequestsPerHour;
  }

  void recordRequest() {
    _requestTimestamps.add(DateTime.now().millisecondsSinceEpoch);
  }

  void reset() {
    _requestTimestamps.clear();
  }

  void _cleanOldTimestamps() {
    final oneHourAgoMs = DateTime.now().millisecondsSinceEpoch - (60 * 60 * 1000);
    _requestTimestamps.removeWhere((ts) => ts < oneHourAgoMs);
  }
}

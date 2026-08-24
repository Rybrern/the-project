import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/media_api_config.dart';
import '../models/animated_wallpaper.dart';
import '../state/quality_settings_controller.dart';
import '../utils/wallpaper_content_filter.dart';

/// Catálogo de videos de Pixabay (https://pixabay.com/api/docs/#api_search_videos)
/// para usar como fondos de pantalla animados. Todo el contenido de video de
/// Pixabay es horizontal (no hay filtro de orientación como en su API de
/// imágenes): el recorte al centro para pantallas verticales se hace del
/// lado nativo con `MediaPlayer.setVideoScalingMode`.
class PixabayVideoService {
  PixabayVideoService({this.quality = AnimatedQuality.balanced});

  /// Preferencia de calidad del usuario (`QualitySettingsController`):
  /// determina qué tier de video de Pixabay se descarga. "small" pesa una
  /// fracción de "medium"/"large", que son notablemente más lentos de bajar
  /// antes de aplicar el fondo.
  final AnimatedQuality quality;

  static const _baseUrl = 'https://pixabay.com/api/videos/';
  static const _perPage = 30;

  Future<List<AnimatedWallpaper>> search(String query) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'key': pixabayApiKey,
      'q': query,
      'safesearch': 'true',
      'per_page': '$_perPage',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Pixabay devolvió ${response.statusCode} para "$query"');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final hits = (body['hits'] as List<dynamic>).cast<Map<String, dynamic>>();
    return hits.map(_mapHit).whereType<AnimatedWallpaper>().toList();
  }

  Future<List<AnimatedWallpaper>> trending() => search('live wallpaper');

  AnimatedWallpaper? _mapHit(Map<String, dynamic> hit) {
    final videos = hit['videos'] as Map<String, dynamic>;
    final tier = _pickTier(videos);
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
      id: 'pixabay_${hit['id']}',
      previewImageUrl: tier['thumbnail'] as String,
      videoUrl: tier['url'] as String,
      width: width,
      height: height,
    );
  }

  /// Orden de tiers preferidos según la calidad elegida por el usuario, con
  /// fallback al siguiente si Pixabay no ofrece ese tier para este video.
  Map<String, dynamic>? _pickTier(Map<String, dynamic> videos) {
    final preferredOrder = switch (quality) {
      AnimatedQuality.balanced => const ['small', 'tiny', 'medium'],
      AnimatedQuality.high => const ['medium', 'small'],
      AnimatedQuality.maximum => const ['large', 'medium'],
    };
    for (final tierName in preferredOrder) {
      final tier = videos[tierName];
      if (tier is Map<String, dynamic>) return tier;
    }
    return null;
  }
}

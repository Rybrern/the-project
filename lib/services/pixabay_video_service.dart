import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/media_api_config.dart';
import '../models/animated_wallpaper.dart';
import '../state/quality_settings_controller.dart';
import '../utils/wallpaper_content_filter.dart';
import 'utils/timeout_helper.dart';

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

    final response = await TimeoutHelper.withTimeout(
      http.get(uri),
      timeout: const Duration(seconds: 15),
      operation: 'Pixabay Video Search: $query',
    );
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

  /// Selecciona el mejor tier disponible según la calidad elegida.
  ///
  /// Implementa fallback: si el tier preferido no existe, intenta los siguientes
  /// en orden de preferencia. NUNCA descarta un video solo porque no tenga el
  /// tier exacto solicitado. La calidad es una preferencia, no un filtro.
  ///
  /// Orden de búsqueda:
  /// - Calidad equilibrada: small → tiny → medium → large
  /// - Calidad alta: medium → small → large → tiny
  /// - Calidad máxima: large → medium → small → tiny
  Map<String, dynamic>? _pickTier(Map<String, dynamic> videos) {
    final preferredOrder = switch (quality) {
      AnimatedQuality.balanced => const ['small', 'tiny', 'medium', 'large'],
      AnimatedQuality.high => const ['medium', 'small', 'large', 'tiny'],
      AnimatedQuality.maximum => const ['large', 'medium', 'small', 'tiny'],
    };

    // Buscar en orden de preferencia
    for (final tierName in preferredOrder) {
      final tier = videos[tierName];
      if (tier is Map<String, dynamic>) return tier;
    }

    // FALLBACK: Si no encuentra ninguno en preferencias, usar el primero disponible
    // Esto asegura que NO se descarten videos válidos solo porque no tengan el tier exacto
    for (final entry in videos.entries) {
      if (entry.value is Map<String, dynamic>) {
        debugPrint(
          'PixabayVideoService: Video no tiene tier preferido para $quality, '
          'usando fallback: ${entry.key}',
        );
        return entry.value as Map<String, dynamic>;
      }
    }

    // Solo retorna null si el video está completamente vacío (no debería ocurrir)
    return null;
  }
}

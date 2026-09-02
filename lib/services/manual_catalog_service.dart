import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wallpaper.dart';

/// Catálogo manual curado por vos via links directos.
///
/// Flujo para agregar fondos sin tocar código Dart:
///  1. Subí la imagen a un host con link directo (Imgur direct link, Catbox, Firebase Storage, Cloudinary, tu VPS).
///     El link debe terminar en .jpg/.png/.webp y ser https con CORS permitido.
///  2. Agregá una entrada en `assets/manual_catalog.json` (ver `manual_catalog.example.json`).
///  3. `flutter run` / rebuild — el `HybridWallpaperService` lo fusiona automáticamente con Wallhaven.
///
/// Validación incluida: filtra URLs no https, resoluciones <1080p y fileTypes gif.
class ManualCatalogService {
  static const _assetPath = 'assets/manual_catalog.json';

  Future<List<Wallpaper>> loadManualWallpapers() async {
    try {
      final jsonStr = await rootBundle.loadString(_assetPath);
      final List<dynamic> raw = jsonDecode(jsonStr) as List<dynamic>;
      final wallpapers = <Wallpaper>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final w = _mapEntry(entry);
        if (w != null) wallpapers.add(w);
      }
      if (kDebugMode) {
        debugPrint('ManualCatalogService: ${wallpapers.length} fondos manuales cargados');
      }
      return wallpapers;
    } catch (e) {
      if (e is FlutterError && e.message.contains('Unable to load asset')) {
        // Asset no existe aún (primera instalación) — no es error.
        return const [];
      }
      debugPrint('ManualCatalogService error: $e');
      return const [];
    }
  }

  Wallpaper? _mapEntry(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final fullUrl = j['fullUrl'] as String? ?? j['url'] as String?;
    if (id == null || fullUrl == null) return null;
    if (!fullUrl.startsWith('https://')) {
      debugPrint('ManualCatalogService: descartado $id — URL debe ser https');
      return null;
    }
    final lower = fullUrl.toLowerCase();
    if (lower.endsWith('.gif') || lower.contains('.gif?')) {
      debugPrint('ManualCatalogService: descartado $id — GIF baja calidad no permitido');
      return null;
    }
    final w = (j['width'] as num?)?.toInt();
    final h = (j['height'] as num?)?.toInt();
    if (w != null && h != null) {
      final shortSide = w < h ? w : h;
      final longSide = w > h ? w : h;
      if (shortSide < 1080 || longSide < 1920) {
        debugPrint('ManualCatalogService: descartado $id — resolución ${w}x$h < 1080p, se verá pixelado');
        return null;
      }
    }
    final category = (j['category'] as String?) ?? 'manual';
    final thumb = j['thumbnailUrl'] as String? ?? fullUrl;
    final aspectRatio = (w != null && h != null && h != 0) ? w / h : 16 / 9;

    return Wallpaper(
      id: id,
      thumbnailUrl: thumb,
      fullUrl: fullUrl,
      author: (j['author'] as String?) ?? 'Manual',
      category: category,
      aspectRatio: aspectRatio.toDouble(),
      forcePortraitCrop: j['forcePortraitCrop'] as bool? ?? true,
      source: 'manual',
      sourceId: id,
      originalUrl: fullUrl,
      tags: (j['tags'] as List<dynamic>?)?.cast<String>(),
      width: w,
      height: h,
      fileType: j['fileType'] as String? ?? 'image/jpeg',
      qualityScore: (w != null && h != null) ? _score(w, h) : 0.8,
      previewUrl: thumb,
    );
  }

  double _score(int w, int h) {
    final p = w * h;
    if (p >= 3840 * 2160) return 1.0;
    if (p >= 2560 * 1440) return 0.9;
    if (p >= 1920 * 1080) return 0.8;
    return 0.5;
  }
}

import '../../database/daos/wallpaper_resolution_dao.dart';
import '../../models/wallpaper.dart';
import '../../state/quality_settings_controller.dart';

/// Selecciona la URL correcta para un wallpaper según calidad y resoluciones disponibles
class ProgressiveUrlSelector {
  /// Selecciona URLs para carga progresiva
  /// Retorna: (thumbnailUrl, previewUrl, originalUrl)
  static ({String thumbnail, String? preview, String? original}) selectUrls(
    Wallpaper wallpaper,
    List<WallpaperResolution>? resolutions,
  ) {
    String? previewUrl;
    String? originalUrl;

    if (resolutions != null && resolutions.isNotEmpty) {
      final previewRes = resolutions.firstWhere(
        (r) => r.resolutionType == 'preview',
        orElse: () => resolutions.first,
      );
      previewUrl = previewRes.url;

      final originalRes = resolutions.firstWhere(
        (r) => r.resolutionType == 'original',
        orElse: () => resolutions.last,
      );
      originalUrl = originalRes.url;
    } else {
      // Fallback: usar fullUrl si no hay resolutions
      originalUrl = wallpaper.fullUrl;
    }

    return (
      thumbnail: wallpaper.thumbnailUrl,
      preview: previewUrl,
      original: originalUrl,
    );
  }

  /// Selecciona la URL final según configuración de calidad
  /// Si hay múltiples resoluciones, elige la que mejor se ajuste a la calidad deseada
  static String? selectUrlByQuality(
    Wallpaper wallpaper,
    List<WallpaperResolution>? resolutions,
    ImageQuality quality,
  ) {
    if (resolutions == null || resolutions.isEmpty) {
      return wallpaper.fullUrl;
    }

    // En el futuro, cuando tengamos múltiples resoluciones (1600px, 2400px, 3200px),
    // aquí seleccionaríamos según la preferencia de calidad
    // Por ahora, retorna el 'original'
    try {
      return resolutions
          .firstWhere((r) => r.resolutionType == 'original')
          .url;
    } catch (e) {
      return wallpaper.fullUrl;
    }
  }

  /// Obtiene el mejor preview URL disponible
  static String? getBestPreviewUrl(
    Wallpaper wallpaper,
    List<WallpaperResolution>? resolutions,
  ) {
    if (resolutions != null && resolutions.isNotEmpty) {
      try {
        return resolutions
            .firstWhere((r) => r.resolutionType == 'preview')
            .url;
      } catch (e) {
        // Si no hay preview, retorna el original
        try {
          return resolutions
              .firstWhere((r) => r.resolutionType == 'original')
              .url;
        } catch (e) {
          return null;
        }
      }
    }
    return wallpaper.fullUrl;
  }
}

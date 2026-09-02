import '../models/wallpaper.dart';
import '../state/quality_settings_controller.dart';

/// Filtra [wallpapers] al piso mínimo de calidad elegido por el usuario.
/// `qualityScore` nulo se trata como `0.8` (Full HD) — mismo fallback que
/// ya usa `manual_catalog_service.dart` cuando falta width/height.
List<Wallpaper> filterByQuality(List<Wallpaper> wallpapers, ImageQuality quality) {
  final threshold = quality.minScore;
  if (threshold <= 0) return wallpapers;
  return wallpapers.where((w) => (w.qualityScore ?? 0.8) >= threshold).toList();
}

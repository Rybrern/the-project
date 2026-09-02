import 'dart:async';

import '../models/category.dart';
import '../models/wallpaper.dart';
import 'manual_catalog_service.dart';
import 'wallhaven_wallpaper_service.dart';
import 'wallpaper_service.dart';

/// Combina Wallhaven (alta calidad, tags oficiales) + catálogo manual por links.
///
/// - Wallhaven ya filtra GIF y <1080p server-side (`atleast`) y client-side.
/// - Manual se valida en `ManualCatalogService` (https, no gif, >=1080p).
/// - Deduplica por `fullUrl` y prioriza manual arriba en la grilla.
class HybridWallpaperService implements WallpaperService {
  HybridWallpaperService({
    required this.wallhavenService,
    ManualCatalogService? manualService,
  }) : _manualService = manualService ?? ManualCatalogService();

  final WallhavenWallpaperService wallhavenService;
  final ManualCatalogService _manualService;

  @override
  Future<List<WallpaperCategory>> fetchCategories() async =>
      wallhavenService.fetchCategories();

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final results = await Future.wait([
      _manualService.loadManualWallpapers(),
      wallhavenService.fetchWallpapers(),
    ]);
    final manual = results[0];
    final remote = results[1];
    return _merge(manual, remote);
  }

  @override
  Stream<List<Wallpaper>> fetchWallpapersStream() {
    final controller = StreamController<List<Wallpaper>>();
    // Cargar manual primero (instantáneo, asset local) luego ir agregando wallhaven en streaming
    _manualService.loadManualWallpapers().then((manual) {
      if (controller.isClosed) return;
      // Emitir manual inmediatamente para que la grilla no quede vacía
      final dedup = <String, Wallpaper>{for (final w in manual) w.fullUrl: w};
      controller.add(List.unmodifiable(dedup.values));

      // Suscribir al stream de wallhaven y fusionar incrementalmente
      wallhavenService.fetchWallpapersStream().listen(
        (batch) {
          for (final w in batch) {
            dedup.putIfAbsent(w.fullUrl, () => w);
          }
          if (!controller.isClosed) {
            // Orden: manual primero, luego wallhaven orden estable
            final merged = [
              ...manual,
              ...dedup.values.where((w) => w.source != 'manual'),
            ];
            controller.add(List.unmodifiable(merged));
          }
        },
        onDone: () => controller.close(),
        onError: (e) {
          // Si wallhaven falla, al menos queda el manual
          if (!controller.isClosed) controller.close();
        },
      );
    });
    return controller.stream;
  }

  List<Wallpaper> _merge(List<Wallpaper> manual, List<Wallpaper> remote) {
    final seen = <String>{};
    final merged = <Wallpaper>[];
    for (final w in manual) {
      if (seen.add(w.fullUrl)) merged.add(w);
    }
    for (final w in remote) {
      if (seen.add(w.fullUrl)) merged.add(w);
    }
    return merged;
  }
}

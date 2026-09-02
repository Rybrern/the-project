import 'dart:async';

import '../models/category.dart';
import '../models/wallpaper.dart';
import 'manual_catalog_service.dart';
import 'supabase_catalog_service.dart';
import 'wallhaven_wallpaper_service.dart';
import 'wallpaper_service.dart';

/// Combina Supabase remoto (sin update APK) + asset manual + Wallhaven.
///
/// Prioridad: Supabase (instantáneo remoto, editable sin APK) > asset manual > Wallhaven.
/// - Si Supabase no está configurado, funciona solo con asset + Wallhaven (no rompe).
/// - Todos filtran GIF y <1080p.
class HybridWallpaperService implements WallpaperService {
  HybridWallpaperService({
    required this.wallhavenService,
    ManualCatalogService? manualService,
    SupabaseCatalogService? supabaseService,
  })  : _manualService = manualService ?? ManualCatalogService(),
        _supabaseService = supabaseService ?? SupabaseCatalogService();

  final WallhavenWallpaperService wallhavenService;
  final ManualCatalogService _manualService;
  final SupabaseCatalogService _supabaseService;

  @override
  Future<List<WallpaperCategory>> fetchCategories() async =>
      wallhavenService.fetchCategories();

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final results = await Future.wait([
      _supabaseService.fetchPublished(),
      _manualService.loadManualWallpapers(),
      wallhavenService.fetchWallpapers(),
    ]);
    final supabase = results[0];
    final manual = results[1];
    final remote = results[2];
    return _merge([...supabase, ...manual], remote);
  }

  @override
  Stream<List<Wallpaper>> fetchWallpapersStream() {
    final controller = StreamController<List<Wallpaper>>();
    Future.wait([
      _supabaseService.fetchPublished(),
      _manualService.loadManualWallpapers(),
    ]).then((lists) {
      final supabase = lists[0];
      final manual = lists[1];
      final initial = [...supabase, ...manual];
      if (controller.isClosed) return;
      final dedup = <String, Wallpaper>{for (final w in initial) w.fullUrl: w};
      controller.add(List.unmodifiable(dedup.values));

      wallhavenService.fetchWallpapersStream().listen(
        (batch) {
          for (final w in batch) {
            dedup.putIfAbsent(w.fullUrl, () => w);
          }
          if (!controller.isClosed) {
            final merged = [
              ...initial,
              ...dedup.values.where((w) => w.source != 'manual' && w.source != 'supabase'),
            ];
            controller.add(List.unmodifiable(merged));
          }
        },
        onDone: () => controller.close(),
        onError: (e) {
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

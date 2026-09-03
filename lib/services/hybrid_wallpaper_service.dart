import 'dart:async';

import '../models/category.dart';
import '../models/wallpaper.dart';
import 'manual_catalog_service.dart';
import 'nasa_wallpaper_service.dart';
import 'supabase_catalog_service.dart';
import 'wallhaven_wallpaper_service.dart';
import 'wallpaper_service.dart';

/// Combina Supabase remoto (sin update APK) + asset manual + Wallhaven + NASA.
///
/// Prioridad: Supabase (instantáneo remoto, editable sin APK) > asset manual > Wallhaven.
/// - Si Supabase no está configurado, funciona solo con asset + Wallhaven (no rompe).
/// - Todos filtran GIF y <1080p.
/// - NASA aporta solo a la categoría "espacio": es dominio público, sin API
///   key y con límite por IP del dispositivo, así que no compite por una
///   cuota compartida.
class HybridWallpaperService implements WallpaperService {
  HybridWallpaperService({
    required this.wallhavenService,
    ManualCatalogService? manualService,
    SupabaseCatalogService? supabaseService,
    NasaWallpaperService? nasaService,
  })  : _manualService = manualService ?? ManualCatalogService(),
        _supabaseService = supabaseService ?? SupabaseCatalogService(),
        _nasaService = nasaService ?? NasaWallpaperService();

  final WallhavenWallpaperService wallhavenService;
  final ManualCatalogService _manualService;
  final SupabaseCatalogService _supabaseService;
  final NasaWallpaperService _nasaService;

  @override
  Future<List<WallpaperCategory>> fetchCategories() async =>
      wallhavenService.fetchCategories();

  @override
  Future<List<Wallpaper>> fetchWallpapers() async {
    final results = await Future.wait([
      _supabaseService.fetchPublished(),
      _manualService.loadManualWallpapers(),
      wallhavenService.fetchWallpapers(),
      _nasaService.fetchSpaceWallpapers(),
    ]);
    final supabase = results[0];
    final manual = results[1];
    final remote = results[2];
    final nasa = results[3];
    return _merge([...supabase, ...manual], [...remote, ...nasa]);
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

      void emit() {
        if (controller.isClosed) return;
        final merged = [
          ...initial,
          ...dedup.values.where((w) => w.source != 'manual' && w.source != 'supabase'),
        ];
        controller.add(List.unmodifiable(merged));
      }

      // El stream solo puede cerrarse cuando terminaron las dos fuentes
      // remotas: cerrarlo apenas termina Wallhaven descartaría los fondos de
      // la NASA si llegan después, que es lo habitual (son 5 consultas).
      var wallhavenDone = false;
      var nasaDone = false;
      void closeIfDone() {
        if (wallhavenDone && nasaDone && !controller.isClosed) controller.close();
      }

      _nasaService.fetchSpaceWallpapers().then((nasa) {
        for (final w in nasa) {
          dedup.putIfAbsent(w.fullUrl, () => w);
        }
        emit();
      }).whenComplete(() {
        nasaDone = true;
        closeIfDone();
      });

      wallhavenService.fetchWallpapersStream().listen(
        (batch) {
          for (final w in batch) {
            dedup.putIfAbsent(w.fullUrl, () => w);
          }
          emit();
        },
        onDone: () {
          wallhavenDone = true;
          closeIfDone();
        },
        onError: (e) {
          wallhavenDone = true;
          closeIfDone();
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

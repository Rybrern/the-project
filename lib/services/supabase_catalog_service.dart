import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallpaper.dart';

/// Lee fondos remotos de Supabase sin requerir update de APK.
///
/// Tabla `wallpapers` (ver `supabase/schema.sql`).
/// - Si Supabase no está configurado (keys vacías), devuelve [] y no rompe la app.
/// - Valida calidad igual que ManualCatalogService (>=1080p, no gif).
class SupabaseCatalogService {
  SupabaseCatalogService({SupabaseClient? client}) : _client = client;

  // ignore: prefer_initializing_formals - nullable optional
  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<Wallpaper>> fetchPublished({int limit = 100}) async {
    final sb = _supabase;
    if (sb == null) return const [];

    try {
      final rows = await sb
          .from('wallpapers')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 10));

      final wallpapers = <Wallpaper>[];
      for (final row in (rows as List)) {
        final w = _mapRow(row as Map<String, dynamic>);
        if (w != null) wallpapers.add(w);
      }
      if (kDebugMode) debugPrint('SupabaseCatalogService: ${wallpapers.length} remotos');
      return wallpapers;
    } catch (e) {
      debugPrint('SupabaseCatalogService error: $e');
      return const [];
    }
  }

  // Realtime opcional: escuchar inserts sin reiniciar app
  RealtimeChannel? subscribe(void Function(List<Wallpaper>) onUpdate) {
    final sb = _supabase;
    if (sb == null) return null;
    final channel = sb.channel('wallpapers-changes');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'wallpapers',
      callback: (_) async {
        final list = await fetchPublished();
        onUpdate(list);
      },
    );
    channel.subscribe();
    return channel;
  }

  Wallpaper? _mapRow(Map<String, dynamic> r) {
    final id = r['id'] as String?;
    final fullUrl = r['full_url'] as String? ?? r['fullUrl'] as String?;
    if (id == null || fullUrl == null) return null;
    if (!fullUrl.startsWith('https://')) return null;
    if (fullUrl.toLowerCase().contains('.gif')) return null;

    final w = (r['width'] as num?)?.toInt();
    final h = (r['height'] as num?)?.toInt();
    if (w != null && h != null) {
      final shortSide = w < h ? w : h;
      final longSide = w > h ? w : h;
      if (shortSide < 1080 || longSide < 1920) return null;
    }

    final category = (r['category'] as String?) ?? 'manual';
    final thumb = (r['thumbnail_url'] as String?) ?? fullUrl;
    final preview = (r['preview_url'] as String?) ?? thumb;
    final tags = (r['tags'] as List?)?.cast<String>();
    final aspectRatio = (w != null && h != null && h != 0) ? w / h : 16 / 9;

    return Wallpaper(
      id: id,
      thumbnailUrl: thumb,
      fullUrl: fullUrl,
      author: (r['author'] as String?) ?? 'Supabase',
      category: category,
      aspectRatio: aspectRatio.toDouble(),
      forcePortraitCrop: true,
      source: 'supabase',
      sourceId: id,
      originalUrl: fullUrl,
      tags: tags,
      width: w,
      height: h,
      fileSize: (r['file_size'] as num?)?.toInt(),
      fileType: r['file_type'] as String? ?? 'image/jpeg',
      qualityScore: (r['quality_score'] as num?)?.toDouble() ?? (w != null && h != null ? _score(w, h) : 0.8),
      previewUrl: preview,
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

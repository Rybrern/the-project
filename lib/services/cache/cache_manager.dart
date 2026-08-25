import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';

/// Gestiona caché inteligente y sincronización incremental.
class CacheManager {
  CacheManager({required this.processingRecordDAO});

  final ProcessingRecordDAO processingRecordDAO;

  /// Almacena información de última sincronización por categoría
  final Map<String, DateTime> _lastSync = {};

  /// Obtiene si una categoría necesita sincronización
  Future<bool> needsSync(String categoryId, {Duration maxAge = const Duration(days: 7)}) async {
    final lastSync = _lastSync[categoryId];

    if (lastSync == null) {
      // Verifica en BD si se procesó antes
      final records = await processingRecordDAO.getByStatus('processed');
      if (records.isEmpty) {
        return true; // Nunca se procesó
      }

      final newestRecord = records.reduce((a, b) =>
          b.processedAt.millisecondsSinceEpoch > a.processedAt.millisecondsSinceEpoch ? b : a);

      final age = DateTime.now().difference(newestRecord.processedAt);
      return age > maxAge;
    }

    return DateTime.now().difference(lastSync) > maxAge;
  }

  /// Registra última sincronización
  void markSynced(String categoryId) {
    _lastSync[categoryId] = DateTime.now();
    debugPrint('CacheManager: Marked $categoryId as synced');
  }

  /// Obtiene estadísticas de caché
  Future<Map<String, dynamic>> getCacheStats() async {
    final processed = await processingRecordDAO.getCountByStatus('processed');
    final rejected = await processingRecordDAO.getCountByStatus('rejected');

    return {
      'wallpapers_cached': processed,
      'rejected_cached': rejected,
      'last_syncs': _lastSync,
      'cache_size_estimate': processed * 50, // ~50KB por wallpaper en metadatos
    };
  }

  /// Invalida caché de una categoría
  void invalidateCache(String categoryId) {
    _lastSync.remove(categoryId);
    debugPrint('CacheManager: Invalidated cache for $categoryId');
  }

  /// Invalida todo el caché
  void clearCache() {
    _lastSync.clear();
    debugPrint('CacheManager: Cleared all cache');
  }
}

/// Detector de cambios incrementales.
/// Identifica qué necesita reprocessarse.
class IncrementalChangeDetector {
  IncrementalChangeDetector({required this.processingRecordDAO});

  final ProcessingRecordDAO processingRecordDAO;

  /// Obtiene cambios desde última sincronización
  Future<Map<String, dynamic>> detectChanges(
    DateTime since, {
    int limit = 100,
  }) async {
    final records = await processingRecordDAO.getRecentRecords(limit: limit);

    // Filtra por timestamp
    final changes = records.where((r) => r.processedAt.isAfter(since)).toList();

    // Agrupa por tipo
    final grouped = <String, List<dynamic>>{};
    for (final change in changes) {
      final key = change.status;
      grouped[key] ??= [];
      grouped[key]!.add(change);
    }

    return {
      'total_changes': changes.length,
      'changes_by_status': grouped,
      'time_range': {
        'from': since.toIso8601String(),
        'to': DateTime.now().toIso8601String(),
      },
    };
  }

  /// Identifica archivos que cambiaron
  Future<List<String>> getChangedFiles(DateTime since) async {
    final changes = await detectChanges(since);
    final files = <String>{};

    // Extrae URLs de cambios
    // En una implementación real, esto vendría de metadatos
    return files.toList();
  }
}

import 'package:flutter/foundation.dart';

/// Gestor de sincronización móvil
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();

  bool _syncing = false;
  DateTime? _lastSync;
  int _syncedItems = 0;

  factory SyncManager() => _instance;

  SyncManager._internal();

  /// Inicia sincronización
  Future<void> sync({
    bool wifiOnly = true,
    int? maxItems,
  }) async {
    if (_syncing) {
      debugPrint('SyncManager: Already syncing');
      return;
    }

    _syncing = true;
    _syncedItems = 0;

    try {
      debugPrint('SyncManager: Starting sync (wifiOnly=$wifiOnly, maxItems=$maxItems)');

      // Simular sincronización
      await Future.delayed(Duration(seconds: 1));

      _lastSync = DateTime.now();
      _syncedItems = maxItems ?? 100;

      debugPrint('SyncManager: Synced $_syncedItems items');
    } finally {
      _syncing = false;
    }
  }

  /// Sincronización incremental
  Future<void> syncDelta() async {
    if (_lastSync == null) {
      await sync();
      return;
    }

    debugPrint('SyncManager: Syncing changes since $_lastSync');
    _lastSync = DateTime.now();
  }

  bool get isSyncing => _syncing;
  DateTime? get lastSync => _lastSync;
  int get lastSyncedItems => _syncedItems;
}

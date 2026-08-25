import 'package:flutter/foundation.dart';
import 'provider_base.dart';
import 'wallhaven_provider.dart';
import 'pixabay_provider.dart';
import 'giphy_provider.dart';
import 'unsplash_provider.dart';
import 'openverse_provider.dart';

/// Registro centralizado de todos los proveedores disponibles.
/// Gestiona la habilitación, prioridades y acceso a proveedores.
class ProviderRegistry {
  static final ProviderRegistry _instance = ProviderRegistry._internal();

  factory ProviderRegistry() {
    return _instance;
  }

  ProviderRegistry._internal();

  final Map<String, WallpaperProvider> _providers = {};
  final Map<String, bool> _enabledStatus = {};

  /// Inicializa los proveedores por defecto
  void initializeDefaults({
    required String wallhavenApiKey,
    required String pixabayApiKey,
    String? unsplashAccessKey,
    String? giphyApiKey,
  }) {
    register(
      WallhavenProvider(apiKey: wallhavenApiKey),
      enabled: wallhavenApiKey.isNotEmpty,
    );
    register(
      PixabayProvider(apiKey: pixabayApiKey),
      enabled: pixabayApiKey.isNotEmpty,
    );
    register(
      GiphyProvider(apiKey: giphyApiKey ?? ''),
      enabled: (giphyApiKey ?? '').isNotEmpty,
    );
    register(
      UnsplashProvider(accessKey: unsplashAccessKey ?? ''),
      enabled: (unsplashAccessKey ?? '').isNotEmpty,
    );
    register(
      OpenVerseProvider(),
      enabled: true, // OpenVerse is free and doesn't require API key
    );
  }

  /// Registra un nuevo proveedor
  void register(WallpaperProvider provider, {bool enabled = true}) {
    _providers[provider.name] = provider;
    _enabledStatus[provider.name] = enabled;
    debugPrint('ProviderRegistry: Registered provider "${provider.name}"');
  }

  /// Obtiene un proveedor por nombre
  WallpaperProvider? getProvider(String name) {
    return _providers[name];
  }

  /// Obtiene todos los proveedores registrados
  List<WallpaperProvider> getAllProviders({bool onlyEnabled = false}) {
    final providers = _providers.values.toList();
    if (onlyEnabled) {
      providers.retainWhere((p) => isEnabled(p.name));
    }
    // Ordena por prioridad descendente
    providers.sort((a, b) => b.priority.compareTo(a.priority));
    return providers;
  }

  /// Obtiene proveedores habilitados ordenados por prioridad
  List<WallpaperProvider> getEnabledProviders() {
    return getAllProviders(onlyEnabled: true);
  }

  /// Habilita/deshabilita un proveedor
  void setEnabled(String providerName, bool enabled) {
    if (_providers.containsKey(providerName)) {
      _enabledStatus[providerName] = enabled;
      debugPrint(
        'ProviderRegistry: Provider "$providerName" is now ${enabled ? 'enabled' : 'disabled'}',
      );
    }
  }

  /// Verifica si un proveedor está habilitado
  bool isEnabled(String providerName) {
    final enabled = _enabledStatus[providerName] ?? false;
    final provider = _providers[providerName];
    return enabled && (provider?.isEnabled ?? false);
  }

  /// Obtiene estadísticas de todos los proveedores
  Future<Map<String, Map<String, dynamic>>> getStatistics() async {
    final stats = <String, Map<String, dynamic>>{};

    for (final provider in getAllProviders()) {
      try {
        stats[provider.name] = await provider.getStatistics();
      } catch (e) {
        stats[provider.name] = {'error': e.toString()};
      }
    }

    return stats;
  }

  /// Valida la disponibilidad de todos los proveedores
  Future<Map<String, bool>> validateAll() async {
    final validation = <String, bool>{};

    for (final provider in getAllProviders()) {
      try {
        validation[provider.name] = await provider.validate();
      } catch (e) {
        validation[provider.name] = false;
        debugPrint('ProviderRegistry: Validation failed for "${provider.name}": $e');
      }
    }

    return validation;
  }

  /// Cuenta de proveedores registrados
  int get totalProviders => _providers.length;

  /// Cuenta de proveedores habilitados
  int get enabledCount => _enabledStatus.values.where((v) => v).length;

  /// Limpia todos los proveedores (útil para testing)
  void clear() {
    _providers.clear();
    _enabledStatus.clear();
  }
}

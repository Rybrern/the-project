import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'url_validator.dart';

/// [FileService] con timeout acotado. Sin esto, una conexión lenta o
/// colgada deja la petición pendiente indefinidamente y el tile nunca
/// llega a mostrar el error (ni por lo tanto a intentar la siguiente URL
/// del fallback) — viola el requisito de no bloquear la UI indefinidamente.
class _TimeoutFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    return super.get(url, headers: headers).timeout(const Duration(seconds: 12));
  }
}

final _timeoutCacheManager = CacheManager(
  Config(
    'robustImageLoaderCache',
    fileService: _TimeoutFileService(),
  ),
);

/// Widget robusto para cargar imágenes con fallback automático.
///
/// Estrategia:
/// 1. Intenta cargar desde thumbnailUrl (rápido, baja resolución)
/// 2. Si falla, intenta previewUrl (resolución media)
/// 3. Si falla, intenta fullUrl (máxima resolución)
/// 4. Si todas fallan, muestra error
///
/// Un error en una URL no bloquea el widget — sigue intentando con las demás.
class RobustImageLoader extends StatefulWidget {
  const RobustImageLoader({
    super.key,
    required this.thumbnailUrl,
    required this.fullUrl,
    this.previewUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.onUrlFailed,
  });

  final String? thumbnailUrl;
  final String? previewUrl;
  final String fullUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Callback cuando una URL falla (para logging/analytics)
  final void Function(String url)? onUrlFailed;

  @override
  State<RobustImageLoader> createState() => _RobustImageLoaderState();
}

class _RobustImageLoaderState extends State<RobustImageLoader> {
  late String _currentUrl;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = _getNextUrl(null);
  }

  @override
  void didUpdateWidget(RobustImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si las URLs cambiaron, reintentar desde thumbnail
    if (oldWidget.fullUrl != widget.fullUrl ||
        oldWidget.previewUrl != widget.previewUrl ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _hasError = false;
      _currentUrl = _getNextUrl(null);
    }
  }

  /// Obtiene la siguiente URL a intentar (en orden de preferencia)
  String _getNextUrl(String? failedUrl) {
    final failureCache = UrlFailureCache();

    // Marcar la URL fallida (si hay)
    if (failedUrl != null) {
      failureCache.markFailed(failedUrl);
      widget.onUrlFailed?.call(failedUrl);
    }

    // Intentar en orden: thumbnail → preview → full
    final candidates = [
      widget.thumbnailUrl,
      widget.previewUrl,
      widget.fullUrl,
    ];

    // Filtrar URLs vacías
    final nonEmpty = candidates.where((u) => u != null && u.isNotEmpty).cast<String>().toList();

    if (nonEmpty.isEmpty) return widget.fullUrl;

    // Retornar la primera que no ha fallado, o la última si todas fallaron
    return failureCache.getFirstNotFailed(nonEmpty) ?? nonEmpty.last;
  }

  void _onImageError(BuildContext context, Object error, StackTrace? stackTrace) {
    if (mounted) {
      setState(() {
        final nextUrl = _getNextUrl(_currentUrl);
        if (nextUrl == _currentUrl) {
          // Ya probamos todas las URLs y ninguna funcionó
          _hasError = true;
        } else {
          // Hay otra URL para intentar
          _currentUrl = nextUrl;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image_outlined),
          );
    }

    return CachedNetworkImage(
      imageUrl: _currentUrl,
      cacheManager: _timeoutCacheManager,
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.placeholder ??
          Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      errorWidget: (context, url, error) {
        // Intentar siguiente URL en la próxima reconstrucción
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onImageError(context, error, null);
        });
        return widget.placeholder ??
            Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
      },
    );
  }
}

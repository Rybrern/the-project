import 'package:flutter/material.dart';

/// Estrategia de carga progresiva: thumbnail → preview → original
/// Permite mostrar versiones de menor calidad mientras se carga la versión completa
class ProgressiveImageLoader {
  /// Timeouts para cada fase de carga
  static const Duration _thumbnailTimeout = Duration(seconds: 3);
  static const Duration _previewTimeout = Duration(seconds: 8);
  static const Duration _originalTimeout = Duration(seconds: 15);

  /// Carga una imagen de forma progresiva
  /// Retorna un stream que emite diferentes versiones de la imagen
  static Stream<ImageProvider> loadProgressively({
    required String? thumbnailUrl,
    required String? previewUrl,
    required String? originalUrl,
  }) async* {
    ImageProvider? currentImage;

    // Fase 1: Thumbnail
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      try {
        final thumbProvider = NetworkImage(thumbnailUrl);
        // Pequeño delay para simular carga
        await Future.delayed(_thumbnailTimeout);
        currentImage = thumbProvider;
        yield currentImage;
      } catch (e) {
        // Error cargando thumbnail, continuamos
      }
    }

    // Fase 2: Preview
    if (previewUrl != null && previewUrl.isNotEmpty) {
      try {
        final previewProvider = NetworkImage(previewUrl);
        // Pequeño delay para simular carga
        await Future.delayed(_previewTimeout);
        currentImage = previewProvider;
        yield currentImage;
      } catch (e) {
        // Error cargando preview, continuamos
      }
    }

    // Fase 3: Original
    if (originalUrl != null && originalUrl.isNotEmpty) {
      try {
        final originalProvider = NetworkImage(originalUrl);
        // Pequeño delay para simular carga
        await Future.delayed(_originalTimeout);
        yield originalProvider;
      } catch (e) {
        // Error cargando original, si tenemos algo lo usamos
        if (currentImage != null) {
          yield currentImage;
        }
      }
    }
  }

  /// Fallback: retorna la mejor URL disponible
  /// Útil para cuando se necesita una URL específica, no un stream
  static String? getBestAvailableUrl({
    required String? thumbnailUrl,
    required String? previewUrl,
    required String? originalUrl,
  }) {
    // Preferir original, sino preview, sino thumbnail
    return originalUrl ?? previewUrl ?? thumbnailUrl;
  }

  /// Retorna URL ordenada por preferencia (para prefetch)
  static List<String> getUrlsInOrder({
    required String? thumbnailUrl,
    required String? previewUrl,
    required String? originalUrl,
  }) {
    return [
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) thumbnailUrl,
      if (previewUrl != null && previewUrl.isNotEmpty) previewUrl,
      if (originalUrl != null && originalUrl.isNotEmpty) originalUrl,
    ];
  }
}

/// Widget que utiliza ProgressiveImageLoader para mostrar imágenes con carga progresiva
class ProgressiveImage extends StatefulWidget {
  const ProgressiveImage({
    super.key,
    this.thumbnailUrl,
    this.previewUrl,
    this.originalUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String? thumbnailUrl;
  final String? previewUrl;
  final String? originalUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage> {
  ImageProvider? _imageProvider;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImageProgressively();
  }

  @override
  void didUpdateWidget(ProgressiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si las URLs cambiaron, recargar
    if (oldWidget.originalUrl != widget.originalUrl ||
        oldWidget.previewUrl != widget.previewUrl ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _loadImageProgressively();
    }
  }

  void _loadImageProgressively() {
    _hasError = false;
    _imageProvider = null;

    ProgressiveImageLoader.loadProgressively(
      thumbnailUrl: widget.thumbnailUrl,
      previewUrl: widget.previewUrl,
      originalUrl: widget.originalUrl,
    ).listen(
      (imageProvider) {
        if (mounted) {
          setState(() {
            _imageProvider = imageProvider;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _imageProvider == null) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          );
    }

    if (_imageProvider == null) {
      return widget.placeholder ??
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    return Image(
      image: _imageProvider!,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ??
            Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            );
      },
    );
  }
}

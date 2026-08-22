import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Vista previa que conserva el ancho extra de los fondos panorámicos.
///
/// En un fondo más ancho que la pantalla, muestra la imagen a la altura del
/// dispositivo y permite arrastrarla horizontalmente para explorarla. Los
/// fondos verticales mantienen el comportamiento habitual de `BoxFit.cover`.
class PannableWallpaperPreview extends StatefulWidget {
  const PannableWallpaperPreview({
    super.key,
    required this.imageUrl,
    required this.aspectRatio,
  });

  final String imageUrl;
  final double aspectRatio;

  @override
  State<PannableWallpaperPreview> createState() =>
      _PannableWallpaperPreviewState();
}

class _PannableWallpaperPreviewState extends State<PannableWallpaperPreview> {
  final TransformationController _controller = TransformationController();
  bool _hasCenteredPanorama = false;

  @override
  void didUpdateWidget(covariant PannableWallpaperPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasCenteredPanorama = false;
      _controller.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerPanorama(double imageWidth, double viewportWidth) {
    if (_hasCenteredPanorama) return;
    _hasCenteredPanorama = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = Matrix4.translationValues(
        -(imageWidth - viewportWidth) / 2,
        0,
        0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final isPanorama = widget.aspectRatio > viewportWidth / viewportHeight;

        if (!isPanorama) {
          return CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => const _PreviewPlaceholder(),
            errorWidget: (_, _, _) => const _PreviewError(),
          );
        }

        // A la altura del viewport, el ancho calculado reproduce toda la
        // composición horizontal sin recortarla para ajustarla a portrait.
        final imageWidth = viewportHeight * widget.aspectRatio;
        _centerPanorama(imageWidth, viewportWidth);

        return Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              transformationController: _controller,
              constrained: false,
              panAxis: PanAxis.horizontal,
              minScale: 1,
              maxScale: 1,
              child: SizedBox(
                width: imageWidth,
                height: viewportHeight,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.fill,
                  placeholder: (_, _) => const _PreviewPlaceholder(),
                  errorWidget: (_, _, _) => const _PreviewError(),
                ),
              ),
            ),
            const IgnorePointer(
              child: Align(
                alignment: Alignment(0, 0.45),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x99000000),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Deslizá para explorar',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF202020),
    child: Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}

class _PreviewError extends StatelessWidget {
  const _PreviewError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF202020),
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white),
    ),
  );
}

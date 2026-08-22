import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Selector de encuadre para convertir una panorámica en un fondo vertical.
class WallpaperCropScreen extends StatefulWidget {
  const WallpaperCropScreen({
    super.key,
    required this.imageUrl,
    required this.aspectRatio,
  });

  final String imageUrl;
  final double aspectRatio;

  @override
  State<WallpaperCropScreen> createState() => _WallpaperCropScreenState();
}

class _WallpaperCropScreenState extends State<WallpaperCropScreen> {
  double _alignment = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Elegir encuadre'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = constraints.maxHeight * widget.aspectRatio;
          final maxOffset = (imageWidth - constraints.maxWidth).clamp(
            0.0,
            double.infinity,
          );

          return Column(
            children: [
              Expanded(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: -maxOffset * _alignment,
                        top: 0,
                        bottom: 0,
                        width: imageWidth,
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.fill,
                          placeholder: (_, _) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.white70, width: 2),
                              right: BorderSide(
                                color: Colors.white70,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      const Text(
                        'Deslizá para elegir la parte que querés usar',
                        style: TextStyle(color: Colors.white),
                      ),
                      Slider(
                        value: _alignment,
                        onChanged: (value) =>
                            setState(() => _alignment = value),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_alignment),
                          child: const Text('Usar este encuadre'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

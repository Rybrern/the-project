import 'dart:async';
import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/wallpaper.dart';
import '../utils/wallpaper_image_processor.dart';

enum _CropStatus { loading, ready, applying, error }

/// Editor interactivo mostrado antes de aplicar un fondo: por defecto
/// reproduce el mismo encuadre "cover" centrado que antes era automático e
/// inamovible, pero ahora el usuario puede hacer pinch-zoom, arrastrar para
/// elegir qué parte de la imagen queda visible, y rotar en pasos de 90°.
class WallpaperCropScreen extends StatefulWidget {
  const WallpaperCropScreen({super.key, required this.wallpaper, required this.target});

  final Wallpaper wallpaper;
  final WallpaperTarget target;

  @override
  State<WallpaperCropScreen> createState() => _WallpaperCropScreenState();
}

class _WallpaperCropScreenState extends State<WallpaperCropScreen> with WidgetsBindingObserver {
  final TransformationController _transformController = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();

  _CropStatus _status = _CropStatus.loading;
  String? _errorMessage;

  Uint8List? _currentBytes;
  int _imageWidth = 0;
  int _imageHeight = 0;
  int _quarterTurns = 0;
  bool _isRotating = false;

  // Si el usuario deja la app (la backgroundea) mientras se está
  // descargando/aplicando el fondo, el proceso se cancela — no debe seguir
  // corriendo en segundo plano ni terminar de aplicar algo que el usuario
  // ya no está mirando. No aplica al anuncio recompensado: ese se muestra
  // antes de llegar a esta pantalla, en WallpaperDetailScreen.
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || _cancelled) return;
    if (_status != _CropStatus.loading && _status != _CropStatus.applying) return;
    _cancelled = true;
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _load() async {
    setState(() {
      _status = _CropStatus.loading;
      _errorMessage = null;
    });
    try {
      final response = await http
          .get(Uri.parse(widget.wallpaper.fullUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar la imagen.');
      }
      if (response.bodyBytes.length > 25 * 1024 * 1024) {
        throw Exception('Imagen demasiado grande.');
      }
      final decoded = await compute(decodeSafely, response.bodyBytes);
      if (decoded == null) {
        throw Exception('No se pudo leer la imagen.');
      }
      if (!mounted || _cancelled) return;
      setState(() {
        _currentBytes = response.bodyBytes;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _quarterTurns = 0;
        _status = _CropStatus.ready;
      });
      _centerTransform();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _status = _CropStatus.error;
        _errorMessage = 'Tiempo agotado al descargar la imagen.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CropStatus.error;
        _errorMessage = 'No se pudo cargar la imagen para editar.';
      });
    }
  }

  /// Tamaño (en píxeles lógicos de pantalla) al que hay que dibujar la
  /// imagen para que cubra exactamente el viewport, igual que `BoxFit.cover`
  /// — pero ahora como tamaño explícito del hijo del InteractiveViewer, para
  /// poder despues invertir el transform y saber qué parte quedó visible.
  Size _coverSize(Size viewport) {
    final imageAspect = _imageWidth / _imageHeight;
    final viewportAspect = viewport.width / viewport.height;
    if (imageAspect > viewportAspect) {
      // Imagen relativamente más ancha: la altura manda.
      return Size(viewport.height * imageAspect, viewport.height);
    }
    return Size(viewport.width, viewport.width / imageAspect);
  }

  void _centerTransform() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final cover = _coverSize(box.size);
      _transformController.value = Matrix4.identity()
        ..translateByDouble(
          -(cover.width - box.size.width) / 2,
          -(cover.height - box.size.height) / 2,
          0,
          1,
        );
    });
  }

  Future<void> _rotate() async {
    if (_currentBytes == null || _isRotating) return;
    setState(() => _isRotating = true);
    try {
      final rotated = await compute(rotateJpeg, (_currentBytes!, 1));
      final decoded = await compute(decodeSafely, rotated);
      if (decoded == null || !mounted) return;
      setState(() {
        _currentBytes = rotated;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _quarterTurns = (_quarterTurns + 1) % 4;
        _isRotating = false;
      });
      _centerTransform();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRotating = false);
      _showSnack('No se pudo rotar la imagen.');
    }
  }

  void _reset() {
    _centerTransform();
  }

  Future<void> _apply() async {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || _currentBytes == null) return;

    setState(() => _status = _CropStatus.applying);
    try {
      final viewportSize = box.size;
      final cover = _coverSize(viewportSize);

      // Rectángulo visible en coordenadas de la imagen "cover" (píxeles
      // lógicos de pantalla), invirtiendo el transform del InteractiveViewer.
      final inverse = Matrix4.inverted(_transformController.value);
      final visible = MatrixUtils.transformRect(
        inverse,
        Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
      );

      // De píxeles lógicos "cover" a píxeles reales de la imagen decodificada.
      final pixelRatio = _imageWidth / cover.width;
      final cropX = (visible.left * pixelRatio).round();
      final cropY = (visible.top * pixelRatio).round();
      final cropWidth = (visible.width * pixelRatio).round();
      final cropHeight = (visible.height * pixelRatio).round();

      final cropped = await compute(
        cropJpeg,
        (_currentBytes!, cropX, cropY, cropWidth, cropHeight),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wallpaper_${widget.wallpaper.id}_crop.jpg');
      await file.writeAsBytes(cropped);

      // Última instancia antes del efecto real (setear el fondo de
      // verdad): si el usuario dejó la app en algún await anterior, no
      // seguir — didChangeAppLifecycleState ya hizo pop(false).
      if (_cancelled) return;

      final result = await AsyncWallpaper.setWallpaper(
        WallpaperRequest(
          target: widget.target,
          sourceType: WallpaperSourceType.file,
          source: file.path,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result.isSuccess);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _status = _CropStatus.ready);
      _showSnack('Tiempo agotado al aplicar el fondo.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _CropStatus.ready);
      _showSnack('No se pudo aplicar el fondo de pantalla.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final targetAspectRatio = screenSize.width / screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ajustar fondo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: targetAspectRatio,
                  child: _buildEditor(),
                ),
              ),
            ),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    switch (_status) {
      case _CropStatus.loading:
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case _CropStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Ocurrió un error.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        );
      case _CropStatus.ready:
      case _CropStatus.applying:
        return ClipRect(
          key: _viewportKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cover = _coverSize(constraints.biggest);
                  return InteractiveViewer(
                    transformationController: _transformController,
                    constrained: false,
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: EdgeInsets.zero,
                    child: SizedBox(
                      width: cover.width,
                      height: cover.height,
                      child: _isRotating
                          ? const ColoredBox(
                              color: Color(0xFF202020),
                              child: Center(child: CircularProgressIndicator(color: Colors.white)),
                            )
                          : Image.memory(_currentBytes!, fit: BoxFit.fill, gaplessPlayback: true),
                    ),
                  );
                },
              ),
              if (_status == _CropStatus.applying)
                Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          ),
        );
    }
  }

  Widget _buildToolbar() {
    final canEdit = _status == _CropStatus.ready && !_isRotating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: canEdit ? _rotate : null,
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
            color: Colors.white,
            tooltip: 'Rotar',
          ),
          IconButton(
            onPressed: canEdit ? _reset : null,
            icon: const Icon(Icons.replay),
            color: Colors.white,
            tooltip: 'Restablecer',
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: canEdit ? _apply : null,
            icon: _status == _CropStatus.applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

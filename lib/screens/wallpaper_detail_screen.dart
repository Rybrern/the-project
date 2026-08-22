import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/wallpaper.dart';
import '../services/ads_service.dart';
import '../state/favorites_controller.dart';
import '../utils/wallpaper_image_processor.dart';
import '../widgets/pannable_wallpaper_preview.dart';
import 'wallpaper_crop_screen.dart';

class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({super.key, required this.wallpaper});

  final Wallpaper wallpaper;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
  static const _panoramaChannel = MethodChannel('wallpaper.font.hd/panorama');

  bool _isDownloading = false;
  bool _isApplying = false;

  // Como mucho un anuncio recompensado por visita a esta pantalla: si ya se
  // vio al descargar, aplicar el fondo después no pide otro (y viceversa).
  bool _adShownThisVisit = false;

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      if (!_adShownThisVisit) {
        final earnedReward = await AdsService.instance.showRewardedAd();
        if (!earnedReward) {
          _showMessage('Mirá el anuncio completo para descargar el fondo.');
          return;
        }
        _adShownThisVisit = true;
      }

      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!hasAccess) {
        _showMessage('Se necesita permiso para guardar en la galería.');
        return;
      }

      final response = await http.get(Uri.parse(widget.wallpaper.fullUrl));
      if (response.statusCode != 200) {
        _showMessage('No se pudo descargar la imagen.');
        return;
      }

      await Gal.putImageBytes(
        response.bodyBytes,
        name: 'wallpaper_${widget.wallpaper.id}',
      );
      _showMessage('Fondo de pantalla guardado en la galería.');
    } catch (_) {
      _showMessage('No se pudo guardar la imagen.');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Mirá este fondo de pantalla: ${widget.wallpaper.fullUrl}',
      ),
    );
  }

  Future<void> _applyWallpaper(
    WallpaperTarget target, {
    double? cropAlignment,
  }) async {
    // Se captura antes del primer await: no se puede usar `context` después
    // de un gap asíncrono si el widget llegó a desmontarse.
    final screenSize = MediaQuery.sizeOf(context);
    final targetAspectRatio = screenSize.width / screenSize.height;

    setState(() => _isApplying = true);
    try {
      if (!_adShownThisVisit) {
        final earnedReward = await AdsService.instance.showRewardedAd();
        if (!earnedReward) {
          _showMessage('Mirá el anuncio completo para aplicar el fondo.');
          return;
        }
        _adShownThisVisit = true;
      }

      WallpaperRequest request;

      // La ruta de archivo es la más compatible con MIUI para los fondos de
      // móvil y permite aplicar el encuadre que seleccionó el usuario.
      final shouldCrop =
          cropAlignment != null || widget.wallpaper.forcePortraitCrop;
      if (shouldCrop) {
        final response = await http.get(Uri.parse(widget.wallpaper.fullUrl));
        if (response.statusCode != 200) {
          _showMessage('No se pudo descargar la imagen.');
          return;
        }

        // Recorta al centro para que coincida con la proporción de la
        // pantalla del teléfono, incluso si el fondo original es horizontal.
        final cropped = await compute(cropToAspectRatio, (
          response.bodyBytes,
          targetAspectRatio,
          cropAlignment ?? 0.5,
        ));

        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/wallpaper_${widget.wallpaper.id}.jpg',
        );
        await file.writeAsBytes(cropped);

        request = WallpaperRequest(
          target: target,
          sourceType: WallpaperSourceType.file,
          source: file.path,
        );
      } else {
        // Fondos pensados para tablets/pantallas horizontales: se aplican
        // tal cual, sin forzar un recorte vertical que arruinaría el encuadre.
        request = WallpaperRequest(
          target: target,
          sourceType: WallpaperSourceType.url,
          source: widget.wallpaper.fullUrl,
        );
      }

      final result = await AsyncWallpaper.setWallpaper(request);
      _showMessage(
        result.isSuccess
            ? 'Fondo de pantalla aplicado.'
            : 'No se pudo aplicar el fondo de pantalla.',
      );
    } catch (_) {
      _showMessage('No se pudo aplicar el fondo de pantalla.');
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showTargetPicker({double? cropAlignment}) async {
    final target = await showModalBottomSheet<WallpaperTarget>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Pantalla de inicio'),
              onTap: () => Navigator.of(context).pop(WallpaperTarget.home),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Pantalla de bloqueo'),
              onTap: () => Navigator.of(context).pop(WallpaperTarget.lock),
            ),
            ListTile(
              leading: const Icon(Icons.smartphone),
              title: const Text('Ambas pantallas'),
              onTap: () => Navigator.of(context).pop(WallpaperTarget.both),
            ),
          ],
        ),
      ),
    );
    if (target != null) {
      await _applyWallpaper(target, cropAlignment: cropAlignment);
    }
  }

  Future<void> _selectCrop() async {
    final alignment = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => WallpaperCropScreen(
          imageUrl: widget.wallpaper.fullUrl,
          aspectRatio: widget.wallpaper.aspectRatio,
        ),
      ),
    );
    if (alignment != null && mounted) {
      await _showTargetPicker(cropAlignment: alignment);
    }
  }

  Future<void> _applyPannableWallpaper() async {
    setState(() => _isApplying = true);
    try {
      if (!_adShownThisVisit) {
        final earnedReward = await AdsService.instance.showRewardedAd();
        if (!earnedReward) {
          _showMessage('Mirá el anuncio completo para aplicar el fondo.');
          return;
        }
        _adShownThisVisit = true;
      }

      final response = await http.get(Uri.parse(widget.wallpaper.fullUrl));
      if (response.statusCode != 200) {
        _showMessage('No se pudo descargar la imagen.');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/pannable_${widget.wallpaper.id}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      final opened = await _panoramaChannel.invokeMethod<bool>(
        'setPannableWallpaper',
        {'path': file.path},
      );
      _showMessage(
        opened == true
            ? 'Confirmá el fondo panorámico en la pantalla de Android.'
            : 'No se pudo abrir el selector de fondo panorámico.',
      );
    } on PlatformException catch (_) {
      _showMessage('No se pudo preparar el fondo panorámico.');
    } catch (_) {
      _showMessage('No se pudo aplicar el fondo panorámico.');
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final isFavorite = favorites.isFavorite(widget.wallpaper.id);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            color: isFavorite ? Colors.redAccent : Colors.white,
            onPressed: () => favorites.toggle(widget.wallpaper.id),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PannableWallpaperPreview(
            imageUrl: widget.wallpaper.fullUrl,
            aspectRatio: widget.wallpaper.aspectRatio,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Por ${widget.wallpaper.author}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: Icons.share_outlined,
                            label: 'Compartir',
                            onPressed: _share,
                          ),
                          _ActionButton(
                            icon: Icons.download_outlined,
                            label: 'Descargar',
                            onPressed: _isDownloading ? null : _download,
                            loading: _isDownloading,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isApplying ? null : _showTargetPicker,
                          icon: _isApplying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.wallpaper),
                          label: const Text('Usar como fondo de pantalla'),
                        ),
                      ),
                      if (widget.wallpaper.aspectRatio > 1) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _isApplying
                                ? null
                                : _applyPannableWallpaper,
                            icon: const Icon(Icons.swipe),
                            label: const Text(
                              'Usar fondo panorámico desplazable',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            onPressed: _isApplying ? null : _selectCrop,
                            icon: const Icon(Icons.crop),
                            label: const Text('Elegir encuadre'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

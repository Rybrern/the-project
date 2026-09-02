import 'dart:async';
import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/wallpaper.dart';
import '../services/ads_service.dart';
import '../state/favorites_controller.dart';
import '../utils/wallpaper_image_processor.dart';

class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({super.key, required this.wallpaper});

  final Wallpaper wallpaper;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
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

      final response = await http
          .get(Uri.parse(widget.wallpaper.fullUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        _showMessage('No se pudo descargar la imagen.');
        return;
      }
      // Validación de tamaño (máx 25MB) para evitar OOM con imágenes maliciosas
      if (response.bodyBytes.length > 25 * 1024 * 1024) {
        _showMessage('Imagen demasiado grande para descargar.');
        return;
      }
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.isNotEmpty && !contentType.startsWith('image/')) {
        _showMessage('El archivo no es una imagen válida.');
        return;
      }

      await Gal.putImageBytes(
        response.bodyBytes,
        name: 'wallpaper_${widget.wallpaper.id}',
      );
      _showMessage('Fondo de pantalla guardado en la galería.');
    } on TimeoutException {
      _showMessage('Tiempo agotado al descargar la imagen.');
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

  Future<void> _applyWallpaper(WallpaperTarget target) async {
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

      if (widget.wallpaper.forcePortraitCrop) {
        final response = await http
            .get(Uri.parse(widget.wallpaper.fullUrl))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          _showMessage('No se pudo descargar la imagen.');
          return;
        }
        if (response.bodyBytes.length > 25 * 1024 * 1024) {
          _showMessage('Imagen demasiado grande.');
          return;
        }

        // Recorta al centro para que coincida con la proporción de la
        // pantalla del teléfono, incluso si el fondo original es horizontal.
        final cropped = await compute(cropToAspectRatio, (
          response.bodyBytes,
          targetAspectRatio,
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
    } on TimeoutException {
      _showMessage('Tiempo agotado al descargar la imagen.');
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

  Future<void> _showTargetPicker() async {
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
      await _applyWallpaper(target);
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
          CachedNetworkImage(
            imageUrl: widget.wallpaper.fullUrl,
            fit: BoxFit.cover,
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
                        'Por ${widget.wallpaper.author}${widget.wallpaper.width != null ? ' • ${widget.wallpaper.width}x${widget.wallpaper.height}' : ''}${widget.wallpaper.source == 'manual' ? ' • Manual' : ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (widget.wallpaper.tags != null && widget.wallpaper.tags!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: widget.wallpaper.tags!
                              .take(8)
                              .map((t) => Chip(
                                    label: Text(t, style: const TextStyle(fontSize: 11)),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.white24,
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ))
                              .toList(),
                        ),
                      ],
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

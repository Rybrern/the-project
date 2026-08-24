import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/animated_wallpaper.dart';
import '../services/ads_service.dart';
import '../state/quality_settings_controller.dart';

class AnimatedWallpaperDetailScreen extends StatefulWidget {
  const AnimatedWallpaperDetailScreen({super.key, required this.wallpaper});

  final AnimatedWallpaper wallpaper;

  @override
  State<AnimatedWallpaperDetailScreen> createState() =>
      _AnimatedWallpaperDetailScreenState();
}

class _AnimatedWallpaperDetailScreenState
    extends State<AnimatedWallpaperDetailScreen> {
  static const _channel = MethodChannel('wallpaper.font.hd/video_wallpaper');

  // Registro propio de "último fondo aplicado con éxito" por destino: no hay
  // forma de que Android nos diga qué video específico está mostrando (el
  // componente del live wallpaper es el mismo sin importar el archivo
  // cargado adentro) ni qué imagen quedó en la pantalla de bloqueo. Del lado
  // de "inicio" esto se combina con `isActiveHomeWallpaper` (nativo) para no
  // confiar ciegamente en el registro si el usuario cambió el fondo desde
  // otro lado; del lado de "bloqueo" no hay ninguna forma de verificar
  // contra el sistema, así que es 100% autogestionado.
  static const _lastHomeIdKey = 'animated_last_applied_home_id';
  static const _lastLockIdKey = 'animated_last_applied_lock_id';

  late final VideoPlayerController _controller;
  bool _isApplying = false;

  // Como mucho un anuncio recompensado por visita a esta pantalla, sin
  // importar cuántas de las dos acciones (video/imagen) termine disparando
  // "Ambas".
  bool _adShownThisVisit = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.wallpaper.videoUrl))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Aplicar un fondo animado en Android ya implica un flujo del sistema en
  // dos pasos (vista previa → elegir "pantalla principal" u "pantalla
  // principal y bloqueada") que no se puede saltear ni preconfigurar desde
  // la app. Agregar acá ARRIBA un tercer menú propio preguntando lo mismo
  // resultaba en 3 pantallas consecutivas pidiendo básicamente la misma
  // decisión. Por eso los dos botones son acciones directas e
  // independientes (sin sheet intermedio), y "también en la de bloqueo" se
  // ofrece como una acción rápida en el aviso de después, no como una
  // pregunta previa.
  Future<void> _applyHome() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyApplied = prefs.getString(_lastHomeIdKey) == widget.wallpaper.id &&
        await _isActiveHomeWallpaper();
    if (alreadyApplied) {
      _showMessage('Este fondo ya está aplicado en la pantalla principal.');
      return;
    }

    setState(() => _isApplying = true);
    try {
      final ok = await _applyHomeVideo();
      if (!ok) {
        _showMessage('No se pudo aplicar el fondo animado.');
        return;
      }
      await prefs.setString(_lastHomeIdKey, widget.wallpaper.id);
      _showHomeAppliedMessage();
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _applyLock() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastLockIdKey) == widget.wallpaper.id) {
      _showMessage('Este fondo ya está aplicado en la pantalla de bloqueo.');
      return;
    }

    setState(() => _isApplying = true);
    try {
      final ok = await _applyLockImage();
      if (ok) await prefs.setString(_lastLockIdKey, widget.wallpaper.id);
      _showMessage(
        ok
            ? 'Imagen aplicada en la pantalla de bloqueo.'
            : 'No se pudo aplicar el fondo de bloqueo.',
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  /// Compara el componente de live wallpaper activo en el sistema contra el
  /// nuestro (`VideoWallpaperService`). Evita confiar ciegamente en el
  /// registro guardado si el usuario cambió el fondo desde otro lado (otra
  /// app, Temas de MIUI, etc.) entre una visita y la siguiente.
  Future<bool> _isActiveHomeWallpaper() async {
    try {
      final isActive = await _channel.invokeMethod<bool>('isActiveHomeWallpaper');
      return isActive == true;
    } on PlatformException {
      return false;
    }
  }

  void _showHomeAppliedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tocá "Pantalla principal" en la pantalla de Android para confirmar.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'También en bloqueo', onPressed: _applyLock),
      ),
    );
  }

  Future<bool> _applyHomeVideo() async {
    try {
      // Se descarga en paralelo a mostrar el anuncio en vez de esperar a que
      // termine para recién empezar: para cuando el usuario cierra el
      // anuncio, el video suele estar listo o casi, en vez de sumar las dos
      // esperas una atrás de la otra.
      final downloadFuture = http.get(Uri.parse(widget.wallpaper.videoUrl));

      if (!await _ensureAdShown()) return false;

      final response = await downloadFuture;
      if (response.statusCode != 200) return false;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/animated_${widget.wallpaper.id}.mp4');
      await file.writeAsBytes(response.bodyBytes);

      final applied = await _channel.invokeMethod<bool>('setVideoWallpaper', {
        'path': file.path,
      });
      return applied == true;
    } on PlatformException {
      return false;
    }
  }

  // Android no permite fondos animados (WallpaperService) en la pantalla de
  // bloqueo, solo en la de inicio: es una limitación del sistema operativo,
  // no de la app. Como mejor alternativa, se usa la miniatura estática del
  // mismo contenido como fondo de bloqueo.
  Future<bool> _applyLockImage() async {
    try {
      if (!await _ensureAdShown()) return false;

      final result = await AsyncWallpaper.setWallpaper(
        WallpaperRequest(
          target: WallpaperTarget.lock,
          sourceType: WallpaperSourceType.url,
          source: widget.wallpaper.previewImageUrl,
        ),
      );
      return result.isSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureAdShown() async {
    if (_adShownThisVisit) return true;
    final earnedReward = await AdsService.instance.showRewardedAd();
    if (!earnedReward) {
      _showMessage('Mirá el anuncio completo para aplicar el fondo.');
      return false;
    }
    _adShownThisVisit = true;
    return true;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final quality = context.watch<QualitySettingsController>().animatedQuality;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (_controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedQualitySelector(
                    quality: quality,
                    onChanged: _isApplying
                        ? null
                        : (value) => context
                            .read<QualitySettingsController>()
                            .setAnimatedQuality(value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _isApplying ? null : _applyHome,
                      icon: _isApplying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.wallpaper, size: 24),
                      label: const Text('Establecer fondo animado'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: _isApplying ? null : _applyLock,
                      icon: const Icon(Icons.lock_outline, size: 20),
                      label: const Text('Usar imagen fija en pantalla de bloqueo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector rápido "Calidad: Equilibrada ▾" para no obligar a ir a Ajustes
/// cada vez que se quiere aplicar un fondo animado con otro nivel de calidad.
class _AnimatedQualitySelector extends StatelessWidget {
  const _AnimatedQualitySelector({required this.quality, required this.onChanged});

  final AnimatedQuality quality;
  final ValueChanged<AnimatedQuality>? onChanged;

  static const _labels = {
    AnimatedQuality.balanced: 'Equilibrada',
    AnimatedQuality.high: 'Alta',
    AnimatedQuality.maximum: 'Máxima',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Calidad: ', style: TextStyle(color: Colors.white70)),
          DropdownButton<AnimatedQuality>(
            value: quality,
            dropdownColor: Theme.of(context).colorScheme.surface,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            iconEnabledColor: Colors.white70,
            onChanged: onChanged == null
                ? null
                : (value) {
                    if (value != null) onChanged!(value);
                  },
            items: [
              for (final entry in _labels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../models/animated_wallpaper.dart';
import '../services/pixabay_video_service.dart';
import '../state/quality_settings_controller.dart';
import 'animated_wallpaper_detail_screen.dart';

/// Grilla de fondos animados (Pixabay Video). Vive embebida (sin
/// Scaffold/AppBar propios) dentro de `WallpapersTab`.
class AnimatedWallpapersTab extends StatefulWidget {
  const AnimatedWallpapersTab({super.key});

  @override
  State<AnimatedWallpapersTab> createState() => _AnimatedWallpapersTabState();
}

class _AnimatedWallpapersTabState extends State<AnimatedWallpapersTab> {
  Future<List<AnimatedWallpaper>>? _wallpapersFuture;
  AnimatedQuality? _loadedForQuality;

  Future<List<AnimatedWallpaper>> _load(AnimatedQuality quality) =>
      PixabayVideoService(quality: quality).trending();

  @override
  Widget build(BuildContext context) {
    final quality = context.watch<QualitySettingsController>().animatedQuality;
    // Solo se vuelve a pedir el catálogo si la calidad elegida cambió (o es
    // la primera carga); cambiar de sub-tab y volver no debería relanzar el
    // fetch con la misma calidad de siempre.
    if (_loadedForQuality != quality) {
      _loadedForQuality = quality;
      _wallpapersFuture = _load(quality);
    }

    return FutureBuilder<List<AnimatedWallpaper>>(
      future: _wallpapersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final wallpapers = snapshot.data!;
        if (wallpapers.isEmpty) {
          return const Center(child: Text('No se pudieron cargar fondos animados.'));
        }

        return MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: wallpapers.length,
          itemBuilder: (context, index) {
            final wallpaper = wallpapers[index];
            return _AnimatedWallpaperTile(
              wallpaper: wallpaper,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnimatedWallpaperDetailScreen(wallpaper: wallpaper),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AnimatedWallpaperTile extends StatelessWidget {
  const _AnimatedWallpaperTile({required this.wallpaper, required this.onTap});

  final AnimatedWallpaper wallpaper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: wallpaper.aspectRatio.clamp(0.5, 2.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: wallpaper.previewImageUrl,
                fit: BoxFit.cover,
              ),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

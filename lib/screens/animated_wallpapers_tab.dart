import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/animated_wallpaper.dart';
import '../services/image_loading/robust_image_loader.dart';
import '../services/search/remote_animated_service.dart';
import 'animated_wallpaper_detail_screen.dart';

/// Grilla de fondos animados. Catálogo desde Firestore (Pixabay Video +
/// GIPHY, actualizado por la Cloud Function de ingesta). Vive embebida
/// (sin Scaffold/AppBar propios) dentro de `WallpapersTab`.
class AnimatedWallpapersTab extends StatefulWidget {
  const AnimatedWallpapersTab({super.key});

  @override
  State<AnimatedWallpapersTab> createState() => _AnimatedWallpapersTabState();
}

class _AnimatedWallpapersTabState extends State<AnimatedWallpapersTab> {
  late Future<List<AnimatedWallpaper>> _wallpapersFuture;

  @override
  void initState() {
    super.initState();
    _wallpapersFuture = RemoteAnimatedService().trending();
  }

  void _retry() {
    setState(() {
      _wallpapersFuture = RemoteAnimatedService().trending();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AnimatedWallpaper>>(
      future: _wallpapersFuture,
      builder: (context, snapshot) {
        // Manejo de error
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Error al cargar fondos animados:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        // Carga en progreso
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final wallpapers = snapshot.data!;
        if (wallpapers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 48),
                const SizedBox(height: 16),
                const Text('No se pudieron cargar fondos animados.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
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
              RobustImageLoader(
                thumbnailUrl: wallpaper.previewImageUrl,
                previewUrl: wallpaper.previewVideoUrl,
                fullUrl: wallpaper.videoUrl,
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

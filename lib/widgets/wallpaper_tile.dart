import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallpaper.dart';
import '../state/favorites_controller.dart';

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key, required this.wallpaper, required this.onTap});

  final Wallpaper wallpaper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final isFavorite = favorites.isFavorite(wallpaper.id);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: wallpaper.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: wallpaper.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ColoredBox(
                  color: Color(0xFFE0E0E0),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => const ColoredBox(
                  color: Color(0xFFE0E0E0),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 20,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: () => favorites.toggle(wallpaper.id),
                  ),
                ),
              ),
              if (wallpaper.source == 'manual')
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Manual', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              if (wallpaper.qualityScore != null && wallpaper.qualityScore! >= 0.9)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      wallpaper.width != null && wallpaper.width! >= 3840 ? '4K' : 'HD',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

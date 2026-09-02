import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../models/wallpaper.dart';
import '../state/favorites_controller.dart';
import '../state/quality_settings_controller.dart';
import '../utils/wallpaper_quality_filter.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key, required this.wallpapersFuture});

  final Future<List<Wallpaper>> wallpapersFuture;

  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<FavoritesController>().favoriteIds;
    final quality = context.watch<QualitySettingsController>().quality;

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder<List<Wallpaper>>(
        future: wallpapersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final favorites = filterByQuality(
            snapshot.data!.where((w) => favoriteIds.contains(w.id)).toList(),
            quality,
          );
          if (favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text(
                      'Todavía no marcaste fondos como favoritos.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final wallpaper = favorites[index];
              return WallpaperTile(
                wallpaper: wallpaper,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WallpaperDetailScreen(wallpaper: wallpaper)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

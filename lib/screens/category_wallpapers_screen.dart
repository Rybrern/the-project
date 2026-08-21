import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

class CategoryWallpapersScreen extends StatelessWidget {
  const CategoryWallpapersScreen({super.key, required this.category, required this.wallpapers});

  final WallpaperCategory category;
  final List<Wallpaper> wallpapers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${category.emoji} ${category.name}')),
      body: MasonryGridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: wallpapers.length,
        itemBuilder: (context, index) {
          final wallpaper = wallpapers[index];
          return WallpaperTile(
            wallpaper: wallpaper,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WallpaperDetailScreen(wallpaper: wallpaper)),
            ),
          );
        },
      ),
    );
  }
}

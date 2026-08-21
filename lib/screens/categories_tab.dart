import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../widgets/category_card.dart';
import 'category_wallpapers_screen.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key, required this.categoriesFuture, required this.wallpapersFuture});

  final Future<List<WallpaperCategory>> categoriesFuture;
  final Future<List<Wallpaper>> wallpapersFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait([categoriesFuture, wallpapersFuture]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data![0] as List<WallpaperCategory>;
          final wallpapers = snapshot.data![1] as List<Wallpaper>;
          final coverByCategory = <String, String>{};
          for (final wallpaper in wallpapers) {
            coverByCategory.putIfAbsent(wallpaper.category, () => wallpaper.thumbnailUrl);
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return CategoryCard(
                category: category,
                coverUrl: coverByCategory[category.id],
                onTap: () {
                  final filtered = wallpapers.where((w) => w.category == category.id).toList();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryWallpapersScreen(category: category, wallpapers: filtered),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../widgets/category_chip.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key, required this.wallpapersFuture, required this.categoriesFuture});

  final Future<List<Wallpaper>> wallpapersFuture;
  final Future<List<WallpaperCategory>> categoriesFuture;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fondos de pantalla')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait([widget.wallpapersFuture, widget.categoriesFuture]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final wallpapers = snapshot.data![0] as List<Wallpaper>;
          final categories = snapshot.data![1] as List<WallpaperCategory>;
          final filtered = _selectedCategoryId == null
              ? wallpapers
              : wallpapers.where((w) => w.category == _selectedCategoryId).toList();

          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CategoryChip(
                        label: 'Todos',
                        selected: _selectedCategoryId == null,
                        onSelected: () => setState(() => _selectedCategoryId = null),
                      );
                    }
                    final category = categories[index - 1];
                    return CategoryChip(
                      label: '${category.emoji} ${category.name}',
                      selected: _selectedCategoryId == category.id,
                      onSelected: () => setState(() => _selectedCategoryId = category.id),
                    );
                  },
                ),
              ),
              Expanded(
                child: MasonryGridView.count(
                  padding: const EdgeInsets.all(12),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final wallpaper = filtered[index];
                    return WallpaperTile(
                      wallpaper: wallpaper,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WallpaperDetailScreen(wallpaper: wallpaper),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../state/quality_settings_controller.dart';
import '../utils/wallpaper_quality_filter.dart';
import '../widgets/category_chip.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key, required this.wallpapersStream, required this.categoriesFuture});

  final Stream<List<Wallpaper>> wallpapersStream;
  final Future<List<WallpaperCategory>> categoriesFuture;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final quality = context.watch<QualitySettingsController>().quality;
    return Scaffold(
      appBar: AppBar(title: const Text('Fondos de pantalla')),
      body: FutureBuilder<List<WallpaperCategory>>(
        future: widget.categoriesFuture,
        builder: (context, categorySnapshot) {
          final categories = categorySnapshot.data ?? const [];

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
                child: StreamBuilder<List<Wallpaper>>(
                  stream: widget.wallpapersStream,
                  builder: (context, snapshot) {
                    final rawWallpapers = snapshot.data ?? const [];
                    final stillLoading = snapshot.connectionState != ConnectionState.done;

                    if (rawWallpapers.isEmpty) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      return const Center(child: CircularProgressIndicator());
                    }

                    final wallpapers = filterByQuality(rawWallpapers, quality);
                    final filtered = _selectedCategoryId == null
                        ? wallpapers
                        : wallpapers.where((w) => w.category == _selectedCategoryId).toList();

                    return Column(
                      children: [
                        // Barra fina: sigue habiendo categorías cargando en
                        // segundo plano mientras la grilla ya es usable.
                        if (stillLoading) const LinearProgressIndicator(minHeight: 2),
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
              ),
            ],
          );
        },
      ),
    );
  }
}

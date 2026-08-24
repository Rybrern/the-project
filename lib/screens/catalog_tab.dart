import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../state/orientation_preference_controller.dart';
import '../utils/wallpaper_orientation_filter.dart';
import '../widgets/category_chip.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

/// Grilla de fondos estáticos con filtro por categoría. Vive embebida (sin
/// Scaffold/AppBar propios) dentro de `WallpapersTab`, que es quien pone el
/// título y las acciones de la barra superior.
class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key, required this.wallpapersStream, required this.categoriesFuture});

  final Stream<List<Wallpaper>> wallpapersStream;
  final Future<List<WallpaperCategory>> categoriesFuture;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String? _selectedCategoryId;

  Future<void> _toggleShowMismatched(bool value) async {
    final orientationPrefs = context.read<OrientationPreferenceController>();
    if (!value) {
      await orientationPrefs.setShowMismatched(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Ver fondos descuadrados?'),
        content: const Text(
          'Tu pantalla es angosta: los fondos horizontales pueden verse '
          'recortados o forzados si los aplicás. ¿Querés verlos igual en el '
          'catálogo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ver igual'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await orientationPrefs.setShowMismatched(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceFitsWide = deviceFitsWideWallpapers(context);
    final orientationPrefs = context.watch<OrientationPreferenceController>();

    return FutureBuilder<List<WallpaperCategory>>(
      future: widget.categoriesFuture,
      builder: (context, categorySnapshot) {
        final categories = categorySnapshot.data ?? const [];

        return Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
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
                  if (!deviceFitsWide)
                    IconButton(
                      tooltip: orientationPrefs.showMismatched
                          ? 'Ocultar fondos descuadrados'
                          : 'Ver fondos descuadrados',
                      icon: Icon(
                        orientationPrefs.showMismatched
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                      ),
                      onPressed: () =>
                          _toggleShowMismatched(!orientationPrefs.showMismatched),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Wallpaper>>(
                stream: widget.wallpapersStream,
                builder: (context, snapshot) {
                  final wallpapers = snapshot.data ?? const [];
                  final stillLoading = snapshot.connectionState != ConnectionState.done;

                  if (wallpapers.isEmpty) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    return const Center(child: CircularProgressIndicator());
                  }

                  final byCategory = _selectedCategoryId == null
                      ? wallpapers
                      : wallpapers.where((w) => w.category == _selectedCategoryId).toList();
                  final filtered = filterByOrientation(
                    byCategory,
                    deviceFitsWide: deviceFitsWide,
                    showMismatched: orientationPrefs.showMismatched,
                  );

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
    );
  }
}

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

/// Grilla de fondos estáticos con filtro por categoría y paginación lazy.
/// Carga páginas bajo demanda mientras el usuario scrollea.
class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key, required this.wallpapersFuture, required this.categoriesFuture});

  // IMPORTANTE: recibe el Future YA CREADO por HomeShell (única suscripción a
  // `stream.last`), en vez de un Stream propio. Un broadcast stream no
  // bufferea eventos: cualquier segunda suscripción hecha aquí (p.ej. con
  // `stream.last` otra vez) puede llegar tarde y no recibir nada, lo que
  // producía "Bad state: No element". Reutilizar el mismo Future evita crear
  // una segunda suscripción por completo.
  final Future<List<Wallpaper>> wallpapersFuture;
  final Future<List<WallpaperCategory>> categoriesFuture;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String? _selectedCategoryId;
  late ScrollController _scrollController;
  final List<Wallpaper> _bufferedWallpapers = [];
  bool _isLoadingMore = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Detecta cuando el usuario scrollea cerca del final y carga más items
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreIfNeeded();
    }
  }

  /// Carga la siguiente página si no hay una carga en progreso
  void _loadMoreIfNeeded() {
    if (!_isLoadingMore && _bufferedWallpapers.length > _currentPage * 20) {
      setState(() {
        _isLoadingMore = true;
      });
      Future.delayed(const Duration(milliseconds: 100)).then((_) {
        if (mounted) {
          setState(() {
            _currentPage++;
            _isLoadingMore = false;
          });
        }
      });
    }
  }

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

    return FutureBuilder<List<Object>>(
      future: Future.wait([widget.categoriesFuture, widget.wallpapersFuture]),
      builder: (context, snapshot) {
        final categories = (snapshot.data?[0] as List<WallpaperCategory>?) ?? const [];
        final allWallpapers = (snapshot.data?[1] as List<Wallpaper>?) ?? const [];

        if (allWallpapers.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Actualizar buffer con todos los wallpapers
        _bufferedWallpapers
          ..clear()
          ..addAll(allWallpapers);

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
              child: Builder(
                builder: (context) {
                  if (allWallpapers.isEmpty) {
                    return const Center(child: Text('No hay fondos disponibles'));
                  }

                  // Aplicar filtros de categoría y orientación
                  final byCategory = _selectedCategoryId == null
                      ? allWallpapers
                      : allWallpapers.where((w) => w.category == _selectedCategoryId).toList();
                  final filtered = filterByOrientation(
                    byCategory,
                    deviceFitsWide: deviceFitsWide,
                    showMismatched: orientationPrefs.showMismatched,
                  );

                  // Calcular items a mostrar basado en página actual
                  const pageSize = 20;
                  final maxItems = _currentPage * pageSize;
                  final displayedItems = filtered.take(maxItems).toList();

                  return MasonryGridView.count(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: displayedItems.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Mostrar loading indicator al final si está cargando
                      if (index == displayedItems.length) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final wallpaper = displayedItems[index];
                      return WallpaperTile(
                        wallpaper: wallpaper,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WallpaperDetailScreen(wallpaper: wallpaper),
                          ),
                        ),
                      );
                    },
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

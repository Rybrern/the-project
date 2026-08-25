import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import 'animated_wallpapers_tab.dart';
import 'catalog_tab.dart';
import 'search_tab.dart';

/// Pantalla "Fondos": un solo AppBar con sub-pestañas Estáticos/Animados/Búsqueda,
/// para separar claramente los dos tipos de contenido sin duplicar título ni
/// barra superior.
class WallpapersTab extends StatefulWidget {
  const WallpapersTab({
    super.key,
    required this.wallpapersStream,
    required this.categoriesFuture,
    this.initialTabIndex = 0,
  });

  final Stream<List<Wallpaper>> wallpapersStream;
  final Future<List<WallpaperCategory>> categoriesFuture;

  /// 0 = Estáticos, 1 = Animados, 2 = Búsqueda. Permite que "Inicio" abra directo en la
  /// sub-pestaña que el usuario pidió.
  final int initialTabIndex;

  @override
  State<WallpapersTab> createState() => _WallpapersTabState();
}

class _WallpapersTabState extends State<WallpapersTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTabIndex,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fondos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image_outlined), text: 'Estáticos'),
            Tab(icon: Icon(Icons.movie_outlined), text: 'Animados'),
            Tab(icon: Icon(Icons.search), text: 'Buscar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CatalogTab(
            wallpapersStream: widget.wallpapersStream,
            categoriesFuture: widget.categoriesFuture,
          ),
          const AnimatedWallpapersTab(),
          const SearchTab(),
        ],
      ),
    );
  }
}

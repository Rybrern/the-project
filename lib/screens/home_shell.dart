import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../services/wallpaper_service.dart';
import 'catalog_tab.dart';
import 'categories_tab.dart';
import 'favorites_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.wallpaperService});

  final WallpaperService wallpaperService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final Stream<List<Wallpaper>> _wallpapersStream;
  late final Future<List<Wallpaper>> _wallpapersFuture;
  late final Future<List<WallpaperCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    // Un único stream compartido: la grilla de Inicio lo consume en vivo
    // para ir mostrando fondos a medida que llegan; el resto de las
    // pantallas usa `_wallpapersFuture` (su último valor, ya completo) sin
    // disparar una segunda descarga.
    _wallpapersStream = widget.wallpaperService.fetchWallpapersStream().asBroadcastStream();
    _wallpapersFuture = _wallpapersStream.last;
    _categoriesFuture = widget.wallpaperService.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      CatalogTab(wallpapersStream: _wallpapersStream, categoriesFuture: _categoriesFuture),
      CategoriesTab(categoriesFuture: _categoriesFuture, wallpapersFuture: _wallpapersFuture),
      FavoritesTab(wallpapersFuture: _wallpapersFuture),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
        ],
      ),
    );
  }
}

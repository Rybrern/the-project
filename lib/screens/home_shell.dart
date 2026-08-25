import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/wallpaper.dart';
import '../services/wallpaper_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'categories_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';
import 'wallpapers_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.wallpaperService});

  final WallpaperService wallpaperService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // "Fondos" arranca en Estáticos por defecto, pero la tarjeta "Fondos
  // animados" del hub de Inicio necesita poder abrirlo directo en Animados.
  // Como el tab vive en un IndexedStack (mantiene su estado), cambiarle el
  // `initialTabIndex` no alcanza: hay que forzar una reconstrucción nueva
  // bumpeando la key cuando el usuario lo pide explícitamente desde Inicio.
  int _fondosInitialTab = 0;
  int _fondosInstanceKey = 0;

  late final Stream<List<Wallpaper>> _wallpapersStream;
  late final Future<List<Wallpaper>> _wallpapersFuture;
  late final Future<List<WallpaperCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    // Un único stream compartido: la grilla de Fondos lo consume en vivo
    // para ir mostrando fondos a medida que llegan; el resto de las
    // pantallas usa `_wallpapersFuture` (su último valor, ya completo) sin
    // disparar una segunda descarga.
    _wallpapersStream = widget.wallpaperService.fetchWallpapersStream().asBroadcastStream();
    _wallpapersFuture = _wallpapersStream.last;
    _categoriesFuture = widget.wallpaperService.fetchCategories();
  }

  void _goToFondos({required bool animated}) {
    setState(() {
      _index = 1;
      _fondosInitialTab = animated ? 1 : 0;
      _fondosInstanceKey++;
    });
  }

  void _goToCategorias() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(
        onOpenFondos: _goToFondos,
        onOpenCategorias: _goToCategorias,
        wallpapersFuture: _wallpapersFuture,
      ),
      WallpapersTab(
        key: ValueKey(_fondosInstanceKey),
        wallpapersFuture: _wallpapersFuture,
        categoriesFuture: _categoriesFuture,
        initialTabIndex: _fondosInitialTab,
      ),
      CategoriesTab(categoriesFuture: _categoriesFuture, wallpapersFuture: _wallpapersFuture),
      const SettingsTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.wallpaper_outlined),
                selectedIcon: Icon(Icons.wallpaper),
                label: 'Fondos',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: 'Categorías',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

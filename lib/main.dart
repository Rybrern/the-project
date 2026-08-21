import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/wallhaven_config.dart';
import 'screens/home_shell.dart';
import 'services/wallhaven_wallpaper_service.dart';
import 'state/favorites_controller.dart';

void main() {
  runApp(const WallpaperApp());
}

class WallpaperApp extends StatelessWidget {
  const WallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FavoritesController(),
      child: MaterialApp(
        title: 'Wallpaper App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: HomeShell(wallpaperService: WallhavenWallpaperService(apiKey: wallhavenApiKey)),
      ),
    );
  }
}

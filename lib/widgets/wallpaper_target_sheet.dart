import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/material.dart';

/// Hoja compartida "¿Dónde querés aplicar este fondo?" con 3 acciones
/// independientes (inicio / bloqueo / ambas), usada tanto por fondos
/// estáticos como animados para que el usuario nunca tenga que interpretar
/// una opción combinada.
Future<WallpaperTarget?> showWallpaperTargetSheet(BuildContext context) {
  return showModalBottomSheet<WallpaperTarget>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '¿Dónde querés aplicar este fondo?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Pantalla principal'),
            onTap: () => Navigator.of(context).pop(WallpaperTarget.home),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Pantalla de bloqueo'),
            onTap: () => Navigator.of(context).pop(WallpaperTarget.lock),
          ),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: const Text('Ambas'),
            onTap: () => Navigator.of(context).pop(WallpaperTarget.both),
          ),
        ],
      ),
    ),
  );
}

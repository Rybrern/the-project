import 'package:flutter/material.dart';

import '../models/wallpaper.dart';
import 'favorites_tab.dart';

/// Hub liviano de "Inicio": no trae datos propios, son solo accesos directos
/// a Fondos (estáticos/animados), Categorías y Favoritos. La navegación
/// pesada (grillas, fetch) vive en esas pantallas, no acá.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.onOpenFondos,
    required this.onOpenCategorias,
    required this.wallpapersFuture,
  });

  /// `animated: true` abre Fondos directo en la sub-pestaña "Animados".
  final void Function({required bool animated}) onOpenFondos;
  final VoidCallback onOpenCategorias;
  final Future<List<Wallpaper>> wallpapersFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fondos HD')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Elegí qué tipo de fondo buscás',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.image_outlined,
            title: 'Fondos estáticos',
            subtitle: 'Imágenes en alta calidad para tu pantalla',
            onTap: () => onOpenFondos(animated: false),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.movie_outlined,
            title: 'Fondos animados',
            subtitle: 'Videos en loop para la pantalla principal',
            onTap: () => onOpenFondos(animated: true),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.category_outlined,
            title: 'Explorar categorías',
            subtitle: 'Naturaleza, anime, autos, espacio, deportes y más',
            onTap: onOpenCategorias,
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.favorite_border,
            title: 'Favoritos',
            subtitle: 'Los fondos que marcaste para volver a encontrarlos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FavoritesTab(wallpapersFuture: wallpapersFuture),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

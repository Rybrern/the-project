import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../models/wallpaper.dart';
import '../services/search/remote_search_service.dart';
import '../state/orientation_preference_controller.dart';
import '../utils/wallpaper_orientation_filter.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

/// Pestaña de búsqueda con campo de entrada y resultados
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchService = RemoteSearchService();
  late TextEditingController _searchController;
  List<Wallpaper> _searchResults = [];
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Realiza búsqueda con debouncing
  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _lastQuery = '';
      });
      return;
    }

    if (query == _lastQuery) return;

    _lastQuery = query;
    _performSearch(query);
  }

  /// Ejecuta la búsqueda
  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final results = await _searchService.search(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('SearchTab: Error during search: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceFitsWide = deviceFitsWideWallpapers(context);
    final orientationPrefs = context.watch<OrientationPreferenceController>();

    return Column(
      children: [
        // Campo de búsqueda
        Container(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar fondos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),

        // Indicador de carga
        if (_isSearching)
          const LinearProgressIndicator(minHeight: 2)
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          SizedBox(
            height: 2,
            child: Container(color: Colors.transparent),
          ),

        // Resultados
        Expanded(
          child: _buildResultsView(deviceFitsWide, orientationPrefs),
        ),
      ],
    );
  }

  Widget _buildResultsView(
    bool deviceFitsWide,
    OrientationPreferenceController orientationPrefs,
  ) {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Ingresa texto para buscar',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Sin resultados para "${_searchController.text}"',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Filtrar por orientación
    final filtered = filterByOrientation(
      _searchResults,
      deviceFitsWide: deviceFitsWide,
      showMismatched: orientationPrefs.showMismatched,
    );

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron fondos con la orientación correcta',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
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
    );
  }
}

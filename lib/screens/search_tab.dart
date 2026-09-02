import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../models/wallpaper.dart';
import '../services/wallhaven_wallpaper_service.dart';
import '../state/quality_settings_controller.dart';
import '../utils/wallpaper_quality_filter.dart';
import '../widgets/wallpaper_tile.dart';
import 'wallpaper_detail_screen.dart';

const _suggestedTags = [
  'nature',
  'anime',
  'abstract',
  'space',
  'city',
  'minimal',
  'dark',
  '4k',
];

enum _SearchStatus { idle, loading, success, empty, error }

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.wallhavenService});

  final WallhavenWallpaperService wallhavenService;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestToken = 0;

  _SearchStatus _status = _SearchStatus.idle;
  List<Wallpaper> _results = const [];
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _status = _SearchStatus.idle;
        _results = const [];
        _query = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(trimmed));
  }

  void _searchTag(String tag) {
    _controller.text = tag;
    _controller.selection = TextSelection.collapsed(offset: tag.length);
    _debounce?.cancel();
    _search(tag);
  }

  Future<void> _search(String query) async {
    final token = ++_requestToken;
    setState(() {
      _status = _SearchStatus.loading;
      _query = query;
    });

    try {
      final results = await widget.wallhavenService.searchByTag(query);
      // Si mientras esperábamos el usuario tipeó otra búsqueda, esta
      // respuesta ya está vieja — no pisar resultados más nuevos.
      if (!mounted || token != _requestToken) return;
      setState(() {
        _results = results;
        _status = results.isEmpty ? _SearchStatus.empty : _SearchStatus.success;
      });
    } catch (_) {
      if (!mounted || token != _requestToken) return;
      setState(() => _status = _SearchStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchTag,
              decoration: InputDecoration(
                hintText: 'Buscar por tag (ej: cyberpunk, sunset...)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _onChanged(_controller.text = ''),
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              itemCount: _suggestedTags.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = _suggestedTags[index];
                return ActionChip(
                  label: Text(tag),
                  onPressed: () => _searchTag(tag),
                );
              },
            ),
          ),
          if (_status == _SearchStatus.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _SearchStatus.idle:
        return const _Hint(icon: Icons.search, text: 'Ingresá un tag para buscar');
      case _SearchStatus.loading:
        return _results.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Opacity(opacity: 0.5, child: _buildGrid());
      case _SearchStatus.empty:
        return _Hint(icon: Icons.image_not_supported_outlined, text: 'Sin resultados para «$_query»');
      case _SearchStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No se pudo buscar. Revisá tu conexión.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _search(_query),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      case _SearchStatus.success:
        return _buildGrid();
    }
  }

  Widget _buildGrid() {
    final quality = context.watch<QualitySettingsController>().quality;
    final results = filterByQuality(_results, quality);
    return MasonryGridView.count(
      padding: const EdgeInsets.all(12),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final wallpaper = results[index];
        return WallpaperTile(
          wallpaper: wallpaper,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WallpaperDetailScreen(wallpaper: wallpaper)),
          ),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
}

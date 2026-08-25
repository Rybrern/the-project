import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/wallpaper.dart';
import 'provider_base.dart';

class WallhavenProvider implements WallpaperProvider {
  WallhavenProvider({required this.apiKey});

  final String apiKey;
  static const _baseUrl = 'https://wallhaven.cc/api/v1/search';

  // Safety exclusions aplicados a TODAS las búsquedas
  static const _safetyExclusions =
      '-nsfw -sexy -cleavage -bikini -lingerie -underwear -swimsuit -ecchi '
      '-ahegao -upskirt -pinup -thighs -boobs -butt -ass -bra -panties';

  @override
  String get name => 'wallhaven';

  @override
  String get description => 'Wallhaven.cc - Large wallpaper community';

  @override
  int get priority => 10;

  @override
  bool get isEnabled => apiKey.isNotEmpty;

  @override
  Future<List<Wallpaper>> search(String query, {int limit = 24}) async {
    return searchPaginated(query, page: 1, perPage: limit);
  }

  @override
  Future<List<Wallpaper>> searchPaginated(
    String query, {
    int page = 1,
    int perPage = 24,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'q': '$query $_safetyExclusions',
        'categories': '100', // general only
        'purity': '100', // sfw only
        'sorting': 'random',
        'per_page': '$perPage',
        'page': '$page',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Wallhaven returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      return items.map(_mapItemToWallpaper).toList();
    } catch (error) {
      debugPrint('WallhavenProvider.searchPaginated error: $error');
      return [];
    }
  }

  @override
  Future<List<Wallpaper>> searchByCategory(
    String query, {
    String? aspectRatio,
    int limit = 24,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'q': '$query $_safetyExclusions',
        'categories': '100',
        'purity': '100',
        'sorting': 'random',
        'per_page': '$limit',
        if (aspectRatio != null) 'ratios': aspectRatio,
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Wallhaven returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      return items.map(_mapItemToWallpaper).toList();
    } catch (error) {
      debugPrint('WallhavenProvider.searchByCategory error: $error');
      return [];
    }
  }

  @override
  Future<List<Wallpaper>> getTrending({int limit = 24}) async {
    return search('trending', limit: limit);
  }

  @override
  Future<bool> validate() async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'per_page': '1',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    // Wallhaven no proporciona stats públicas, pero podrías implementar
    // tracking local si lo necesitas
    return {
      'provider': name,
      'available': await validate(),
    };
  }

  @override
  List<String> getAvailableQueries() => [
    'nature', 'landscape', 'space', 'abstract', 'architecture',
    'animals', 'dark', 'art', 'cars', 'motorcycles', 'sports',
    'celebrity', 'movie', 'anime', 'games', 'sci-fi', 'fantasy',
    'technology', 'minimal', 'trending',
  ];

  @override
  Future<void> reset() async {
    // Wallhaven no tiene estado interno que resetear
  }

  Wallpaper _mapItemToWallpaper(Map<String, dynamic> item) {
    final width = (item['dimension_x'] as num).toDouble();
    final height = (item['dimension_y'] as num).toDouble();
    final thumbs = item['thumbs'] as Map<String, dynamic>;
    final tags = (item['tags'] as List<dynamic>?)?.map((t) => (t as Map)['name'] as String).toList();

    return Wallpaper(
      id: 'wallhaven_${item['id']}',
      thumbnailUrl: thumbs['large'] as String? ?? thumbs['small'] as String,
      fullUrl: item['path'] as String,
      author: 'Wallhaven',
      category: 'general',
      aspectRatio: width / height,
      source: 'wallhaven',
      sourceId: item['id'] as String,
      originalUrl: 'https://wallhaven.cc/w/${item['id']}',
      tags: tags,
    );
  }
}

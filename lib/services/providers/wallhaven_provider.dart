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
      final List<dynamic> rawItems = body['data'] as List<dynamic>;

      final List<Wallpaper> wallpapers = [];
      for (final rawItem in rawItems) {
        if (rawItem is Map<String, dynamic>) {
          final wallpaper = _mapItemToWallpaper(rawItem);
          if (wallpaper != null) {
            wallpapers.add(wallpaper);
          }
        }
      }
      return wallpapers;
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
      final List<dynamic> rawItems = body['data'] as List<dynamic>;

      final List<Wallpaper> wallpapers = [];
      for (final rawItem in rawItems) {
        if (rawItem is Map<String, dynamic>) {
          final wallpaper = _mapItemToWallpaper(rawItem);
          if (wallpaper != null) {
            wallpapers.add(wallpaper);
          }
        }
      }
      return wallpapers;
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

  Wallpaper? _mapItemToWallpaper(Map<String, dynamic> item) {
    // Safely extract essential data, returning null if critical fields are missing or invalid.
    final String? path = item['path'] as String?;
    final Map<String, dynamic>? thumbs = item['thumbs'] as Map<String, dynamic>?;
    final String? itemIdNullable = item['id'] as String?; // Use a different name to avoid confusion

    // If critical fields (path, thumbs, or ID) are missing, we cannot create a valid Wallpaper object.
    if (path == null || thumbs == null || itemIdNullable == null) {
      debugPrint('WallhavenProvider: Skipping item due to missing critical data (path, thumbs, or id): ${item['id'] ?? 'unknown ID'}');
      return null; // Discard this item.
    }

    // At this point, itemIdNullable is guaranteed to be non-null.
    final String itemId = itemIdNullable!; // Assert non-nullability

    // Safely extract dimensions.
    final double? width = (item['dimension_x'] as num?)?.toDouble();
    final double? height = (item['dimension_y'] as num?)?.toDouble();

    // Safely extract thumbnail URLs.
    final String? largeThumb = thumbs['large'] as String?;
    final String? smallThumb = thumbs['small'] as String?;
    final String? thumbnailUrl = largeThumb ?? smallThumb;
    final String? previewUrl = largeThumb ?? thumbnailUrl;

    // Safely extract tags.
    final tags = (item['tags'] as List<dynamic>?)?.map((t) => (t as Map)['name'] as String).toList();

    // Construct the Wallpaper object, ensuring all non-nullable fields have valid values.
    // If any required field cannot be constructed, return null.
    final String constructedId = 'wallhaven_$itemId'; // itemId is guaranteed non-null here.
    final String constructedFullUrl = path.startsWith('http')
        ? path
        : 'https://wallhaven.cc/${path.startsWith('/') ? path.substring(1) : path}';
    final String constructedSourceId = itemId; // itemId is guaranteed non-null here.
    final String constructedOriginalUrl = 'https://wallhaven.cc/w/$itemId'; // itemId is guaranteed non-null here.
    final double constructedAspectRatio = (width != null && height != null && height != 0) ? width / height : 1.0; // Defaulted to non-null.

    // All required fields for Wallpaper constructor are now guaranteed to be non-null.
    return Wallpaper(
      id: constructedId,
      thumbnailUrl: thumbnailUrl, // This can be null, and the UI should handle it.
      fullUrl: constructedFullUrl,
      previewUrl: previewUrl,
      author: 'Wallhaven', // Hardcoded non-null.
      category: 'general', // Hardcoded non-null.
      aspectRatio: constructedAspectRatio,
      source: 'wallhaven', // Hardcoded non-null.
      sourceId: constructedSourceId,
      originalUrl: constructedOriginalUrl,
      tags: tags, // This can be null.
    );
  }
}

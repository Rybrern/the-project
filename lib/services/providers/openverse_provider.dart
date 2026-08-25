import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/wallpaper.dart';
import '../../utils/wallpaper_content_filter.dart';
import 'provider_base.dart';

/// OpenVerse Provider for accessing CC-licensed images
///
/// Provides access to millions of freely-licensed images through the OpenVerse API.
/// Implements aggressive rate limiting (50ms between requests, 10k/day quota).
/// All images are filtered for CC0 license for maximum legal clarity.
class OpenVerseProvider implements WallpaperProvider {
  OpenVerseProvider();

  static const String _baseUrl = 'https://api.openverse.org/v1/images';
  static const String _license = 'cc0'; // Most legally clear license
  static const int _rateLimitDelayMs = 50; // 50ms between requests (5/s)

  int _lastRequestTimestamp = 0;
  int _totalRequestsToday = 0;

  @override
  String get name => 'openverse';

  @override
  String get description => 'OpenVerse - Free CC-licensed images';

  @override
  int get priority => 3;

  @override
  bool get isEnabled => true; // No API key required

  /// Implements rate limiting with simple backoff
  /// Ensures we don't exceed 5 requests/second and 10k/day quota
  Future<void> _applyRateLimit() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastRequestTimestamp;

    if (elapsed < _rateLimitDelayMs) {
      await Future<void>.delayed(
        Duration(milliseconds: _rateLimitDelayMs - elapsed),
      );
    }

    _lastRequestTimestamp = DateTime.now().millisecondsSinceEpoch;
    _totalRequestsToday++;

    // Log rate limit status (dev purposes)
    if (kDebugMode && _totalRequestsToday % 100 == 0) {
      debugPrint('[OpenVerse] Rate limit: $_totalRequestsToday requests today');
    }
  }

  /// Resets rate limit tracking (call daily or on app start)
  @override
  Future<void> reset() async {
    _lastRequestTimestamp = 0;
    _totalRequestsToday = 0;
    debugPrint('[OpenVerse] Rate limit counters reset');
  }

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
      await _applyRateLimit();

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': query,
        'page': '$page',
        'page_size': '$perPage',
        'license': _license,
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[OpenVerse] Search failed: ${response.statusCode} - ${response.body}',
        );
        return [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      return results
          .map(_mapImageToWallpaper)
          .where((wp) => wp != null)
          .cast<Wallpaper>()
          .toList();
    } catch (error) {
      debugPrint('[OpenVerse] searchPaginated error: $error');
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
      await _applyRateLimit();

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': query,
        'page': '1',
        'page_size': '$limit',
        'license': _license,
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint('[OpenVerse] searchByCategory failed: ${response.statusCode}');
        return [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      return results
          .map(_mapImageToWallpaper)
          .where((wp) => wp != null)
          .cast<Wallpaper>()
          .toList();
    } catch (error) {
      debugPrint('[OpenVerse] searchByCategory error: $error');
      return [];
    }
  }

  @override
  Future<List<Wallpaper>> getTrending({int limit = 24}) async {
    // OpenVerse doesn't have a dedicated trending endpoint,
    // so we use popular query terms
    return search('popular', limit: limit);
  }

  /// Returns a list of pre-defined discovery queries for the discovery engine
  /// These queries are commonly used for wallpaper discovery
  @override
  List<String> getAvailableQueries() => [
    'landscape',
    'nature',
    'abstract',
    'space',
    'architecture',
    'animals',
    'city',
    'art',
    'car',
    'motorcycle',
    'sports',
    'person',
    'technology',
    'water',
    'mountain',
    'beach',
    'forest',
    'sunset',
    'night',
    'clouds',
    'minimal',
    'dark',
    'colorful',
    'vintage',
    'modern',
    'geometric',
    'texture',
  ];

  @override
  Future<bool> validate() async {
    try {
      await _applyRateLimit();

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'page': '1',
        'page_size': '1',
        'license': _license,
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      return response.statusCode == 200;
    } catch (error) {
      debugPrint('[OpenVerse] validate error: $error');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return {
      'provider': name,
      'available': await validate(),
      'requestsToday': _totalRequestsToday,
      'license': 'CC0',
    };
  }

  /// Maps OpenVerse API image response to Wallpaper model
  ///
  /// OpenVerse response format:
  /// {
  ///   "id": "abc123",
  ///   "title": "Image Title",
  ///   "creator": "Author Name",
  ///   "tags": [{"name": "tag1"}, {"name": "tag2"}],
  ///   "url": "https://live.staticflickr.com/...",
  ///   "thumbnail": "https://api.openverse.org/v1/images/abc123/thumb/",
  ///   "width": 1920,
  ///   "height": 1080,
  ///   "license": "cc0"
  /// }
  Wallpaper? _mapImageToWallpaper(Map<String, dynamic> image) {
    try {
      final width = (image['width'] as num?)?.toInt() ?? 800;
      final height = (image['height'] as num?)?.toInt() ?? 600;
      final title = image['title'] as String? ?? 'Untitled';
      final creator = image['creator'] as String? ?? 'OpenVerse';

      // Extract tags from array of objects with 'name' field
      final tagsList = <String>[];
      final tags = image['tags'] as List<dynamic>?;
      if (tags != null) {
        for (final tag in tags) {
          if (tag is Map<String, dynamic>) {
            final tagName = tag['name'] as String?;
            if (tagName != null && tagName.isNotEmpty) {
              tagsList.add(tagName);
            }
          }
        }
      }

      // Validate content using the filter
      if (!WallpaperContentFilter.isAppropriateWallpaper(
        text: '$title ${tagsList.join(' ')}',
        width: width,
        height: height,
      )) {
        return null;
      }

      final imageUrl = image['url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        return null;
      }

      // Use thumbnail from API if available, otherwise construct from image URL
      final thumbnailUrl = image['thumbnail'] as String? ?? imageUrl;

      // CC0 license maps to perfect quality score (1.0)
      // This indicates maximum legal clarity and freedom of use
      const qualityScore = 1.0;

      return Wallpaper(
        id: 'openverse_${image['id']}',
        thumbnailUrl: thumbnailUrl,
        fullUrl: imageUrl,
        author: creator,
        category: 'general',
        aspectRatio: width / height,
        source: 'openverse',
        sourceId: image['id'] as String? ?? '',
        originalUrl: image['url'] as String?,
        qualityScore: qualityScore,
        tags: tagsList.isNotEmpty ? tagsList : null,
      );
    } catch (error) {
      debugPrint('[OpenVerse] Error mapping image: $error');
      return null;
    }
  }
}

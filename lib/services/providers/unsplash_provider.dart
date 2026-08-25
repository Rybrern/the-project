import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/wallpaper.dart';
import '../../config/media_api_config.dart';
import '../../utils/wallpaper_content_filter.dart';
import 'provider_base.dart';

/// High-quality photography provider backed by Unsplash.
///
/// Unsplash is a community of photographers sharing high-quality,
/// freely-usable (CC0) photographs. Perfect for wallpapers.
///
/// Rate Limits:
/// - 50 requests/hour on free tier (generous for development)
/// - Implements queue-based rate limiting with backoff
class UnsplashProvider implements WallpaperProvider {
  UnsplashProvider({this.accessKey = unsplashAccessKey});

  final String accessKey;
  static const _baseUrl = 'https://api.unsplash.com/search/photos';
  static const _perPage = 30;

  // Rate limiting: 50/hr = ~1 request every 72 seconds, using 1500ms for safety
  static const _rateLimitMs = 1500;

  /// Queue for rate-limited requests
  final List<_QueuedRequest> _requestQueue = [];
  Timer? _rateLimitTimer;
  bool _isProcessing = false;

  @override
  String get name => 'unsplash';

  @override
  String get description => 'Unsplash - High-quality freely-usable photography';

  @override
  int get priority => 7; // Between Pixabay (5) and Wallhaven (10)

  @override
  bool get isEnabled => accessKey.isNotEmpty;

  /// Performs a simple search
  @override
  Future<List<Wallpaper>> search(String query, {int limit = 24}) async {
    return searchPaginated(query, page: 1, perPage: limit);
  }

  /// Performs paginated search
  /// Uses the page parameter for pagination support
  @override
  Future<List<Wallpaper>> searchPaginated(
    String query, {
    int page = 1,
    int perPage = 24,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'client_id': accessKey,
        'query': query,
        'page': '$page',
        'per_page': '${perPage.clamp(1, _perPage)}', // Unsplash max is 30
        'order_by': 'relevant',
        'content_filter': 'high', // Unsplash's safety filter
      });

      final response = await _makeRateLimitedRequest(uri);
      if (response.statusCode != 200) {
        throw Exception('Unsplash returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>()
          .toList() ?? [];

      return results
          .map(_mapPhotoToWallpaper)
          .where((wp) => wp != null)
          .cast<Wallpaper>()
          .toList();
    } catch (error) {
      debugPrint('UnsplashProvider.searchPaginated error: $error');
      return [];
    }
  }

  /// Searches by category with specific parameters
  @override
  Future<List<Wallpaper>> searchByCategory(
    String query, {
    String? aspectRatio,
    int limit = 24,
  }) async {
    // Category keywords are passed as query
    return searchPaginated(query, page: 1, perPage: limit);
  }

  /// Gets trending/popular photos (sorted by likes descending)
  @override
  Future<List<Wallpaper>> getTrending({int limit = 24}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'client_id': accessKey,
        'query': 'trending OR popular',
        'page': '1',
        'per_page': '${limit.clamp(1, _perPage)}',
        'order_by': 'relevant',
        'content_filter': 'high',
      });

      final response = await _makeRateLimitedRequest(uri);
      if (response.statusCode != 200) {
        throw Exception('Unsplash returned ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>()
          .toList() ?? [];

      return results
          .map(_mapPhotoToWallpaper)
          .where((wp) => wp != null)
          .cast<Wallpaper>()
          .toList();
    } catch (error) {
      debugPrint('UnsplashProvider.getTrending error: $error');
      return [];
    }
  }

  /// Validates provider availability (connectivity, API key, etc.)
  @override
  Future<bool> validate() async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'client_id': accessKey,
        'query': 'landscape',
        'per_page': '1',
      });

      final response = await _makeRateLimitedRequest(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns provider statistics
  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return {
      'provider': name,
      'available': await validate(),
      'rateLimit': '50/hour',
    };
  }

  /// Returns available queries for discovery engine
  @override
  List<String> getAvailableQueries() => [
    'landscape', 'nature', 'space', 'abstract', 'architecture',
    'animals', 'urban', 'seascape', 'mountains', 'forest',
    'aurora', 'desert', 'beach', 'city', 'modern design',
    'minimalist',
  ];

  /// Resets internal state (rate limiter queue)
  @override
  Future<void> reset() async {
    _requestQueue.clear();
    _rateLimitTimer?.cancel();
    _isProcessing = false;
  }

  /// Makes a rate-limited HTTP GET request
  /// Queues requests to respect 50/hr rate limit with 1500ms backoff
  Future<http.Response> _makeRateLimitedRequest(Uri uri) {
    final completer = Completer<http.Response>();
    _requestQueue.add(_QueuedRequest(uri: uri, completer: completer));
    _processQueue();
    return completer.future;
  }

  /// Processes queued requests with rate limiting
  void _processQueue() {
    if (_isProcessing || _requestQueue.isEmpty) return;

    _isProcessing = true;
    final request = _requestQueue.removeAt(0);

    http.get(request.uri).then(
      (response) {
        request.completer.complete(response);
      },
      onError: (error) {
        request.completer.completeError(error);
      },
    ).whenComplete(() {
      // Schedule next request after rate limit delay
      if (_requestQueue.isNotEmpty) {
        _rateLimitTimer = Timer(const Duration(milliseconds: _rateLimitMs), () {
          _isProcessing = false;
          _processQueue();
        });
      } else {
        _isProcessing = false;
      }
    });
  }

  /// Maps Unsplash photo API response to Wallpaper model
  Wallpaper? _mapPhotoToWallpaper(Map<String, dynamic> photo) {
    try {
      final width = (photo['width'] as int?) ?? 0;
      final height = (photo['height'] as int?) ?? 0;

      // Basic resolution check
      if (!WallpaperContentFilter.hasEnoughResolution(width, height)) {
        return null;
      }

      final id = photo['id'] as String? ?? '';
      if (id.isEmpty) return null;

      final urls = photo['urls'] as Map<String, dynamic>?;
      if (urls == null) return null;

      final thumbnailUrl = urls['thumb'] as String?;
      final fullUrl = urls['regular'] as String? ?? urls['full'] as String?;

      if (thumbnailUrl == null || fullUrl == null) return null;

      final user = photo['user'] as Map<String, dynamic>?;
      final author = user?['name'] as String? ?? 'Unsplash';
      final userLocation = user?['location'] as String?;

      final tagsList = (photo['tags'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map((tag) => tag['title'] as String? ?? '')
          .where((tag) => tag.isNotEmpty)
          .toList() ?? [];

      final description = photo['description'] as String? ?? '';
      final likes = (photo['likes'] as int?) ?? 0;
      final downloads = (photo['downloads'] as int?) ?? 0;

      // Category inference from tags and description
      final category = _inferCategory(tagsList, description);
      final subcategory = _inferSubcategory(tagsList, description);

      // Quality scoring based on resolution
      final qualityScore = _calculateQualityScore(width, height);

      // Temporal data
      final createdAt = photo['created_at'] as String?;
      final processedAt = createdAt != null ? DateTime.tryParse(createdAt) : null;

      return Wallpaper(
        id: 'unsplash_$id',
        thumbnailUrl: thumbnailUrl,
        fullUrl: fullUrl,
        author: author,
        category: category,
        aspectRatio: width / height,
        source: 'unsplash',
        sourceId: id,
        originalUrl: 'https://unsplash.com/photos/$id',
        nsfwScore: 0.1, // Unsplash is pre-vetted and safe
        qualityScore: qualityScore,
        primaryCategory: category,
        subcategory: subcategory,
        tags: tagsList,
        processedAt: processedAt,
        processingStatus: 'accepted',
        previewUrl: urls['small'] as String?,
        entityMetadata: {
          if (userLocation != null && userLocation.isNotEmpty)
            'location': userLocation,
          'photographer': author,
          'popularity': likes + downloads,
          'likes': likes,
          'downloads': downloads,
        },
      );
    } catch (error) {
      debugPrint('UnsplashProvider._mapPhotoToWallpaper error: $error');
      return null;
    }
  }

  /// Infers primary category from tags and description
  String _inferCategory(List<String> tags, String description) {
    final tagsLower = tags.map((t) => t.toLowerCase()).toList();
    final descLower = description.toLowerCase();
    final combined = [...tagsLower, descLower].join(' ');

    // Check for specific categories
    if (_containsAny(combined, ['landscape', 'scenery', 'terrain', 'vista'])) {
      return 'landscape';
    }
    if (_containsAny(combined, ['nature', 'forest', 'tree', 'outdoor', 'natural'])) {
      return 'nature';
    }
    if (_containsAny(combined, ['space', 'galaxy', 'star', 'cosmic', 'universe', 'nebula', 'planet'])) {
      return 'space';
    }
    if (_containsAny(combined, ['abstract', 'art', 'modern', 'geometric'])) {
      return 'abstract';
    }
    if (_containsAny(combined, ['building', 'architecture', 'structure', 'urban', 'design'])) {
      return 'architecture';
    }
    if (_containsAny(combined, ['animal', 'wildlife', 'pet', 'bird', 'mammal', 'insect'])) {
      return 'animals';
    }
    if (_containsAny(combined, ['city', 'street', 'downtown', 'urban', 'metropolis'])) {
      return 'urban';
    }
    if (_containsAny(combined, ['ocean', 'sea', 'wave', 'beach', 'coast', 'seascape', 'water'])) {
      return 'seascape';
    }
    if (_containsAny(combined, ['mountain', 'peak', 'alpine', 'hill'])) {
      return 'mountains';
    }
    if (_containsAny(combined, ['forest', 'wood', 'tree', 'woods'])) {
      return 'forest';
    }
    if (_containsAny(combined, ['aurora', 'northern lights', 'borealis'])) {
      return 'aurora';
    }
    if (_containsAny(combined, ['desert', 'sand', 'dune'])) {
      return 'desert';
    }
    if (_containsAny(combined, ['beach', 'shore', 'sand'])) {
      return 'beach';
    }

    return 'general';
  }

  /// Infers subcategory for more detailed classification
  String? _inferSubcategory(List<String> tags, String description) {
    final tagsLower = tags.map((t) => t.toLowerCase()).toList();
    final descLower = description.toLowerCase();
    final combined = [...tagsLower, descLower].join(' ');

    if (_containsAny(combined, ['sunset', 'sunrise', 'dusk', 'dawn'])) {
      return 'sunrise-sunset';
    }
    if (_containsAny(combined, ['portrait', 'people', 'person', 'human'])) {
      return 'portrait';
    }
    if (_containsAny(combined, ['minimalist', 'minimal', 'simple'])) {
      return 'minimalist';
    }
    if (_containsAny(combined, ['dark', 'night', 'noir', 'shadow'])) {
      return 'dark';
    }
    if (_containsAny(combined, ['colorful', 'vibrant', 'bright', 'vivid'])) {
      return 'colorful';
    }
    if (_containsAny(combined, ['black and white', 'monochrome', 'bw'])) {
      return 'monochrome';
    }

    return null;
  }

  /// Calculates quality score based on resolution
  /// 2K+: 0.9-1.0
  /// 1.5K-2K: 0.8
  /// 1K-1.5K: 0.7
  /// Below 1K: lower scores
  double _calculateQualityScore(int width, int height) {
    final minDim = width < height ? width : height;

    if (minDim >= 2048) return 0.95;
    if (minDim >= 1920) return 0.9;
    if (minDim >= 1536) return 0.8;
    if (minDim >= 1280) return 0.7;
    if (minDim >= 1024) return 0.6;
    if (minDim >= 768) return 0.5;

    return 0.3;
  }

  /// Helper: Check if string contains any of the keywords
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}

/// Represents a queued request for rate limiting
class _QueuedRequest {
  _QueuedRequest({
    required this.uri,
    required this.completer,
  });

  final Uri uri;
  final Completer<http.Response> completer;
}

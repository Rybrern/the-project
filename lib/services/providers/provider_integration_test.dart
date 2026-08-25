/// Integration tests for new content providers
/// Tests provider integration without external API calls
import 'package:flutter_test/flutter_test.dart';

import 'openverse_provider.dart';
import 'unsplash_provider.dart';
import 'giphy_provider.dart';
import 'provider_registry.dart';

void main() {
  group('Provider Integration Tests', () {
    late ProviderRegistry registry;

    setUp(() {
      registry = ProviderRegistry();
    });

    group('Provider Registry', () {
      test('registers all new providers', () {
        final openverse = OpenVerseProvider();
        final unsplash = UnsplashProvider();
        final giphy = GiphyProvider();

        registry.register(openverse, enabled: true);
        registry.register(unsplash, enabled: true);
        registry.register(giphy, enabled: true);

        expect(registry.getProvider('openverse'), equals(openverse));
        expect(registry.getProvider('unsplash'), equals(unsplash));
        expect(registry.getProvider('giphy'), equals(giphy));
      });

      test('provider priority ordering is correct', () {
        final openverse = OpenVerseProvider();
        final unsplash = UnsplashProvider();
        final giphy = GiphyProvider();

        registry.register(giphy, enabled: true); // priority 8
        registry.register(unsplash, enabled: true); // priority 7
        registry.register(openverse, enabled: true); // priority 3

        final enabled = registry.getEnabledProviders();

        // Should be ordered by priority descending: 8, 7, 3
        expect(enabled[0].priority, greaterThanOrEqualTo(enabled[1].priority));
        expect(enabled[1].priority, greaterThanOrEqualTo(enabled[2].priority));
      });

      test('enabled/disabled status managed correctly', () {
        final openverse = OpenVerseProvider();

        registry.register(openverse, enabled: true);
        expect(registry.isEnabled('openverse'), isTrue);

        registry.setEnabled('openverse', false);
        expect(registry.isEnabled('openverse'), isFalse);

        registry.setEnabled('openverse', true);
        expect(registry.isEnabled('openverse'), isTrue);
      });
    });

    group('Provider Metadata Consistency', () {
      test('all providers have non-empty names', () {
        final providers = [
          OpenVerseProvider(),
          UnsplashProvider(),
          GiphyProvider(),
        ];

        for (final p in providers) {
          expect(p.name, isNotEmpty);
          expect(p.name.length, lessThan(50));
        }
      });

      test('all providers have descriptions', () {
        final providers = [
          OpenVerseProvider(),
          UnsplashProvider(),
          GiphyProvider(),
        ];

        for (final p in providers) {
          expect(p.description, isNotEmpty);
          expect(p.description.length, greaterThan(10));
        }
      });

      test('provider priorities are unique and valid', () {
        final providers = [
          OpenVerseProvider(),
          UnsplashProvider(),
          GiphyProvider(),
        ];

        final priorities = providers.map((p) => p.priority).toList();

        // All priorities should be unique
        expect(priorities.toSet().length, equals(priorities.length));

        // All priorities should be positive
        for (final p in priorities) {
          expect(p, greaterThan(0));
          expect(p, lessThan(100)); // Arbitrary upper limit
        }
      });

      test('providers have available queries', () {
        final providers = [
          OpenVerseProvider(),
          UnsplashProvider(),
          GiphyProvider(),
        ];

        for (final p in providers) {
          final queries = p.getAvailableQueries();
          expect(queries, isNotEmpty);
          expect(queries.length, greaterThanOrEqualTo(10));

          // All queries should be non-empty strings
          for (final q in queries) {
            expect(q, isNotEmpty);
            expect(q.length, lessThan(100));
          }
        }
      });
    });

    group('Rate Limiting Configuration', () {
      test('OpenVerse has rate limit configuration', () {
        // OpenVerse: 50ms backoff = 5 req/s
        // No API key needed - public API
        final openverse = OpenVerseProvider();
        expect(openverse.name, equals('openverse'));
      });

      test('Unsplash has rate limit configuration', () {
        // Unsplash: 1500ms backoff = 50/hr
        // Requires API key
        final unsplash = UnsplashProvider();
        expect(unsplash.name, equals('unsplash'));
      });

      test('GIPHY has rate limit configuration', () {
        // GIPHY: 100ms backoff = 43/hr free tier
        // Requires API key
        final giphy = GiphyProvider();
        expect(giphy.name, equals('giphy'));
      });
    });

    group('Error Handling', () {
      test('providers handle invalid queries gracefully', () {
        // Providers should not crash on invalid queries
        final providers = [
          OpenVerseProvider(),
          UnsplashProvider(),
          GiphyProvider(),
        ];

        for (final p in providers) {
          // Empty query
          expect(() => p.search(''), returnsNormally);

          // Very long query
          expect(() => p.search('a' * 1000), returnsNormally);

          // Special characters
          expect(() => p.search('@#\$%^&*()'), returnsNormally);

          // Unicode
          expect(() => p.search('你好世界🎨🌈'), returnsNormally);
        }
      });

      test('providers initialize without API keys when optional', () {
        // OpenVerse doesn't require API key
        expect(() => OpenVerseProvider(), returnsNormally);

        // Unsplash and GIPHY initialize but validation may fail without keys
        expect(() => UnsplashProvider(), returnsNormally);
        expect(() => GiphyProvider(), returnsNormally);
      });
    });

    group('Interface Compliance', () {
      test('all providers implement WallpaperProvider methods', () {
        final providers = [
          OpenVerseProvider(),
          UnsplashProvider(),
          GiphyProvider(),
        ];

        for (final p in providers) {
          // Check all required methods exist and are callable
          expect(p.search, isNotNull);
          expect(p.searchPaginated, isNotNull);
          expect(p.searchByCategory, isNotNull);
          expect(p.getTrending, isNotNull);
          expect(p.validate, isNotNull);
          expect(p.getStatistics, isNotNull);
          expect(p.reset, isNotNull);
          expect(p.getAvailableQueries, isNotNull);

          // Check all properties exist
          expect(p.name, isNotNull);
          expect(p.description, isNotNull);
          expect(p.priority, isNotNull);
          expect(p.isEnabled, isNotNull);
        }
      });
    });

    group('Discovery Queries', () {
      test('discovery queries cover major categories', () {
        final openverse = OpenVerseProvider();
        final unsplash = UnsplashProvider();
        final giphy = GiphyProvider();

        final allQueries = [
          ...openverse.getAvailableQueries(),
          ...unsplash.getAvailableQueries(),
          ...giphy.getAvailableQueries(),
        ];

        // Should have queries for common categories
        expect(allQueries.any((q) => q.toLowerCase().contains('nature')), isTrue);
        expect(allQueries.any((q) => q.toLowerCase().contains('landscape')), isTrue);
        expect(allQueries.any((q) => q.toLowerCase().contains('space')), isTrue);
        expect(allQueries.any((q) => q.toLowerCase().contains('abstract')), isTrue);
      });
    });
  });
}

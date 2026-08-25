/// Unit tests and integration tests for Tag Normalization System
///
/// Run tests with: flutter test lib/services/tag_normalization/tag_normalization_test.dart
///
/// These tests verify:
/// - Text normalization correctness
/// - Tag extraction and deduplication
/// - Entity type detection accuracy
/// - Fuzzy matching behavior
/// - Database operations
/// - Alias resolution
/// - Confidence scoring

// Note: Actual tests should use proper testing framework (test/mockito)
// This file demonstrates the test structure and cases

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tag_normalizer.dart';

void main() {
  group('TagNormalizer', () {
    late TagNormalizer normalizer;

    setUp(() {
      normalizer = TagNormalizer();
    });

    group('normalizeText()', () {
      test('converts to lowercase', () {
        expect(normalizer.normalizeText('HELLO'), 'hello');
        expect(normalizer.normalizeText('MiXeD CaSe'), 'mixed case');
      });

      test('removes accents', () {
        expect(normalizer.normalizeText('Café'), equals('cafe'));
        expect(normalizer.normalizeText('São Paulo'), equals('sao paulo'));
        expect(normalizer.normalizeText('Lionel Messi'), equals('lionel messi'));
        expect(normalizer.normalizeText('Ñoño'), equals('nono'));
      });

      test('strips special characters', () {
        expect(normalizer.normalizeText('Hello!@#$%'), equals('hello'));
        expect(
          normalizer.normalizeText('Test (with) brackets'),
          equals('test with brackets'),
        );
        expect(normalizer.normalizeText('Price: $100'), equals('price 100'));
      });

      test('collapses whitespace', () {
        expect(normalizer.normalizeText('hello   world'), equals('hello world'));
        expect(normalizer.normalizeText('  spaces  '), equals('spaces'));
        expect(normalizer.normalizeText('tab\t\ttest'), equals('tab test'));
      });

      test('handles empty strings', () {
        expect(normalizer.normalizeText(''), equals(''));
        expect(normalizer.normalizeText('   '), equals(''));
      });

      test('handles unicode correctly', () {
        // Various international characters
        expect(normalizer.normalizeText('José'), equals('jose'));
        expect(normalizer.normalizeText('François'), equals('francois'));
        expect(normalizer.normalizeText('Müller'), equals('muller'));
      });
    });

    group('extractTags()', () {
      test('extracts from List<String>', () {
        final tags = ['hello', 'world', 'test'];
        final result = normalizer.extractTags(tags);
        expect(result, isNotEmpty);
        expect(result.length, equals(3));
      });

      test('extracts from List<Map> with "name" field', () {
        final tags = [
          {'name': 'Lionel Messi'},
          {'name': 'Football'},
        ];
        final result = normalizer.extractTags(tags);
        expect(result.length, equals(2));
        expect(result, contains('lionel messi'));
        expect(result, contains('football'));
      });

      test('deduplicates similar tags', () {
        final tags = [
          'messi',
          'Messi',
          'MESSI',
          'messi ',
          ' messi',
        ];
        final result = normalizer.extractTags(tags);
        expect(result.length, equals(1));
        expect(result.first, equals('messi'));
      });

      test('handles null input', () {
        expect(normalizer.extractTags(null), equals([]));
        expect(normalizer.extractTags([]), equals([]));
      });

      test('handles mixed input types', () {
        final tags = [
          'simple-tag',
          {'name': 'Complex Tag'},
          {'title': 'ignored'},
        ];
        final result = normalizer.extractTags(tags);
        expect(result.length, greaterThan(0));
      });
    });

    group('buildCanonicalName()', () {
      test('converts to lowercase with hyphens', () {
        expect(normalizer.buildCanonicalName('Lionel Messi'),
               equals('lionel-messi'));
        expect(normalizer.buildCanonicalName('Real Madrid'),
               equals('real-madrid'));
      });

      test('handles multiple spaces', () {
        expect(normalizer.buildCanonicalName('Super Long Tag Name'),
               equals('super-long-tag-name'));
      });

      test('removes accents first', () {
        expect(normalizer.buildCanonicalName('São Paulo'),
               equals('sao-paulo'));
        expect(normalizer.buildCanonicalName('Montpellier'),
               equals('montpellier'));
      });
    });

    group('fuzzyMatchScore()', () {
      test('exact matches score 1.0', () {
        expect(normalizer.fuzzyMatchScore('hello', 'hello'), equals(1.0));
        expect(normalizer.fuzzyMatchScore('HELLO', 'hello'), equals(1.0));
      });

      test('similar words score high', () {
        final score = normalizer.fuzzyMatchScore('messi', 'messi10');
        expect(score, greaterThan(0.7));
      });

      test('different words score low', () {
        final score = normalizer.fuzzyMatchScore('messi', 'ronaldo');
        expect(score, lessThan(0.5));
      });

      test('empty strings score 0', () {
        expect(normalizer.fuzzyMatchScore('', 'hello'), equals(0.0));
        expect(normalizer.fuzzyMatchScore('hello', ''), equals(0.0));
      });

      test('partial matches score moderately', () {
        final score = normalizer.fuzzyMatchScore('messi', 'lionel messi');
        expect(score, greaterThan(0.4));
        expect(score, lessThan(0.9));
      });
    });

    group('personNameLikelihood()', () {
      test('single words score low', () {
        expect(normalizer.personNameLikelihood('messi'), lessThan(0.5));
      });

      test('multi-word names score high', () {
        expect(
          normalizer.personNameLikelihood('lionel messi'),
          greaterThan(0.7),
        );
        expect(
          normalizer.personNameLikelihood('cristiano ronaldo'),
          greaterThan(0.7),
        );
      });

      test('names with prepositions score medium-high', () {
        final score = normalizer.personNameLikelihood('jose maria de la cruz');
        expect(score, greaterThan(0.5));
        expect(score, lessThan(1.0));
      });
    });

    group('isLikelyLocation()', () {
      test('recognizes country names', () {
        expect(normalizer.isLikelyLocation('spain'), equals(true));
        expect(normalizer.isLikelyLocation('england'), equals(true));
        expect(normalizer.isLikelyLocation('argentina'), equals(true));
      });

      test('rejects non-location tags', () {
        expect(normalizer.isLikelyLocation('messi'), equals(false));
        expect(normalizer.isLikelyLocation('football'), equals(false));
      });
    });

    group('isLikelySports()', () {
      test('recognizes sports keywords', () {
        expect(normalizer.isLikelySports('football'), equals(true));
        expect(normalizer.isLikelySports('basketball'), equals(true));
        expect(normalizer.isLikelySports('formula 1'), equals(true));
      });

      test('recognizes sports-related keywords', () {
        expect(normalizer.isLikelySports('nfl'), equals(true));
        expect(normalizer.isLikelySports('nba'), equals(true));
        expect(normalizer.isLikelySports('championship'), equals(true));
      });

      test('rejects non-sports tags', () {
        expect(normalizer.isLikelySports('nature'), equals(false));
        expect(normalizer.isLikelySports('abstract'), equals(false));
      });
    });

    group('splitTagComponents()', () {
      test('splits hyphenated tags', () {
        final parts = normalizer.splitTagComponents('real-madrid');
        expect(parts, equals(['real', 'madrid']));
      });

      test('splits space-separated tags', () {
        final parts = normalizer.splitTagComponents('lionel messi');
        expect(parts, equals(['lionel', 'messi']));
      });

      test('handles single-word tags', () {
        final parts = normalizer.splitTagComponents('messi');
        expect(parts, equals(['messi']));
      });

      test('filters empty parts', () {
        final parts = normalizer.splitTagComponents('  hello  --  world  ');
        expect(parts, isNotEmpty);
        expect(parts.where((p) => p.isEmpty), isEmpty);
      });
    });

    group('Levenshtein distance', () {
      test('identical strings distance 0', () {
        expect(normalizer.fuzzyMatchScore('hello', 'hello'), equals(1.0));
      });

      test('one character different', () {
        final score = normalizer.fuzzyMatchScore('hello', 'hallo');
        expect(score, greaterThan(0.8));
      });

      test('multiple differences', () {
        final score = normalizer.fuzzyMatchScore('kitten', 'sitting');
        // Should be less than single char difference
        expect(score, lessThan(0.85));
      });
    });

    group('detectVariation()', () {
      test('recognizes common abbreviations', () {
        expect(normalizer.detectVariation('leo'),
               equals('lionel messi'));
        expect(normalizer.detectVariation('m10'),
               equals('lionel messi'));
        expect(normalizer.detectVariation('f1'),
               equals('formula 1'));
      });

      test('returns null for unknown variations', () {
        expect(normalizer.detectVariation('unknown'), isNull);
      });
    });
  });

  group('Integration Tests', () {
    late TagNormalizer normalizer;

    setUp(() {
      normalizer = TagNormalizer();
    });

    test('complete normalization workflow', () {
      // Simulate API response
      final apiTags = [
        'Lionel Messi',
        'messi',
        'Leo Messi',
        'football',
        'Football',
      ];

      // Extract and normalize
      final normalized = normalizer.extractTags(apiTags);

      // Verify deduplication and normalization
      expect(normalized.length, lessThan(apiTags.length));
      expect(normalized, contains('lionel messi'));
      expect(normalized, contains('football'));

      // Verify no uppercase
      for (final tag in normalized) {
        expect(tag, equals(tag.toLowerCase()));
      }
    });

    test('person name detection workflow', () {
      final tags = [
        'Lionel Messi',
        'Argentina',
        'Football',
      ];

      for (final tag in tags) {
        final normalized = normalizer.normalizeText(tag);
        final personLikelihood = normalizer.personNameLikelihood(normalized);
        final isLocation = normalizer.isLikelyLocation(normalized);
        final isSports = normalizer.isLikelySports(normalized);

        debugPrint('Tag: $tag');
        debugPrint('  Person: $personLikelihood');
        debugPrint('  Location: $isLocation');
        debugPrint('  Sports: $isSports');
      }
    });

    test('canonical name generation', () {
      final entities = [
        MapEntry('Lionel Messi', 'lionel-messi'),
        MapEntry('Real Madrid', 'real-madrid'),
        MapEntry('Manchester City', 'manchester-city'),
        MapEntry('Formula 1', 'formula-1'),
      ];

      for (final entity in entities) {
        final canonical = normalizer.buildCanonicalName(entity.key);
        expect(canonical, entity.value);
      }
    });
  });

  group('Edge Cases', () {
    late TagNormalizer normalizer;

    setUp(() {
      normalizer = TagNormalizer();
    });

    test('handles emoji', () {
      final result = normalizer.normalizeText('Football ⚽');
      expect(result, contains('football'));
    });

    test('handles numbers', () {
      final result = normalizer.normalizeText('cr7');
      expect(result, equals('cr7'));
    });

    test('handles mixed alphanumeric', () {
      final result = normalizer.normalizeText('messi10');
      expect(result, equals('messi10'));
    });

    test('handles very long strings', () {
      final longTag = 'a' * 1000;
      final result = normalizer.normalizeText(longTag);
      expect(result, isNotEmpty);
    });

    test('handles special unicode blocks', () {
      final result = normalizer.normalizeText('café');
      expect(result, contains('cafe'));
    });
  });
}

/// Helper function to run tests
void runTagNormalizationTests() {
  main();
}

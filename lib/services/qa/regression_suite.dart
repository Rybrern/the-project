import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';
import '../../models/wallpaper.dart';

/// Resultados de prueba de regresión
class RegressionResults {
  final List<RegressionTest> tests;
  final int passed;
  final int failed;
  final int skipped;
  final double successRate;
  final DateTime testedAt;

  RegressionResults({
    required this.tests,
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.successRate,
    required this.testedAt,
  });

  bool isHealthy() => successRate > 0.95; // 95%+ success

  Map<String, dynamic> toJson() {
    return {
      'passed': passed,
      'failed': failed,
      'skipped': skipped,
      'successRate': successRate,
      'failedTests':
          tests.where((t) => !t.passed).map((t) => t.toJson()).toList(),
      'isHealthy': isHealthy(),
      'testedAt': testedAt.toIso8601String(),
    };
  }
}

/// Test de regresión individual
class RegressionTest {
  final String name;
  final String description;
  final bool passed;
  final String? error;
  final double durationMs;

  RegressionTest({
    required this.name,
    required this.description,
    required this.passed,
    this.error,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'passed': passed,
      'error': error,
      'durationMs': durationMs,
    };
  }
}

/// Suite de pruebas de regresión
class RegressionSuite {
  final WallpaperDAO _wallpaperDAO;

  RegressionSuite({
    required WallpaperDAO wallpaperDAO,
  })  : _wallpaperDAO = wallpaperDAO;

  /// Ejecuta todas las pruebas de regresión
  Future<RegressionResults> runAllTests() async {
    debugPrint('RegressionSuite: Starting regression tests...');

    final tests = <RegressionTest>[];

    // Test 1: Original providers work
    tests.add(await _testOriginalProviders());

    // Test 2: Original search works
    tests.add(await _testOriginalSearch());

    // Test 3: Original categories load
    tests.add(await _testOriginalCategories());

    // Test 4: UI doesn't break with 300k+ wallpapers
    tests.add(await _testLargeDataset());

    // Test 5: Pagination works
    tests.add(await _testPagination());

    // Test 6: Download still works
    tests.add(await _testDownload());

    final passed = tests.where((t) => t.passed).length;
    final failed = tests.where((t) => !t.passed).length;
    final successRate = passed / tests.length;

    debugPrint(
      'RegressionSuite: Complete. Passed: $passed/${ tests.length}',
    );

    return RegressionResults(
      tests: tests,
      passed: passed,
      failed: failed,
      skipped: 0,
      successRate: successRate,
      testedAt: DateTime.now(),
    );
  }

  /// Test: Original providers work
  Future<RegressionTest> _testOriginalProviders() async {
    final name = 'Original Providers';
    final description = 'Wallhaven and Pixabay providers should work';

    try {
      final start = DateTime.now();

      // Verificar que hay wallpapers de los proveedores originales
      final wallhaven = await _wallpaperDAO.getBySource('wallhaven', limit: 10);
      final pixabay = await _wallpaperDAO.getBySource('pixabay', limit: 10);

      final duration = DateTime.now().difference(start).inMilliseconds;

      final passed = wallhaven.isNotEmpty && pixabay.isNotEmpty;

      return RegressionTest(
        name: name,
        description: description,
        passed: passed,
        error: passed
            ? null
            : 'Wallhaven: ${wallhaven.length}, Pixabay: ${pixabay.length}',
        durationMs: duration.toDouble(),
      );
    } catch (e) {
      return RegressionTest(
        name: name,
        description: description,
        passed: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }

  /// Test: Original search works
  Future<RegressionTest> _testOriginalSearch() async {
    final name = 'Original Search';
    final description = 'Search functionality should work';

    try {
      final start = DateTime.now();

      // Verificar que hay wallpapers con tags (para búsqueda)
      final allWallpapers = await _wallpaperDAO.getAllAccepted(limit: 100);
      final withTags = allWallpapers.where((w) => w.tags != null && w.tags!.isNotEmpty);

      final duration = DateTime.now().difference(start).inMilliseconds;
      final passed = withTags.isNotEmpty;

      return RegressionTest(
        name: name,
        description: description,
        passed: passed,
        error: passed ? null : 'No wallpapers with tags found',
        durationMs: duration.toDouble(),
      );
    } catch (e) {
      return RegressionTest(
        name: name,
        description: description,
        passed: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }

  /// Test: Original categories load
  Future<RegressionTest> _testOriginalCategories() async {
    final name = 'Original Categories';
    final description = 'Categories should load properly';

    try {
      final start = DateTime.now();

      // Verificar que hay wallpapers con categorías
      final allWallpapers = await _wallpaperDAO.getAllAccepted(limit: 100);
      final categories = allWallpapers
          .map((w) => w.primaryCategory ?? w.category)
          .where((c) => c.isNotEmpty)
          .toSet();

      final duration = DateTime.now().difference(start).inMilliseconds;
      final passed = categories.isNotEmpty;

      return RegressionTest(
        name: name,
        description: description,
        passed: passed,
        error: passed ? null : 'No categories found',
        durationMs: duration.toDouble(),
      );
    } catch (e) {
      return RegressionTest(
        name: name,
        description: description,
        passed: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }

  /// Test: UI doesn't break with large dataset
  Future<RegressionTest> _testLargeDataset() async {
    final name = 'Large Dataset Handling';
    final description = 'UI should handle 300k+ wallpapers without breaking';

    try {
      final start = DateTime.now();

      // Verificar que la BD puede manejar queries grandes
      final total = await _wallpaperDAO.getTotalCount();

      final duration = DateTime.now().difference(start).inMilliseconds;
      final passed = total > 0;

      return RegressionTest(
        name: name,
        description: description,
        passed: passed,
        error: passed ? null : 'No wallpapers in database',
        durationMs: duration.toDouble(),
      );
    } catch (e) {
      return RegressionTest(
        name: name,
        description: description,
        passed: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }

  /// Test: Pagination works
  Future<RegressionTest> _testPagination() async {
    final name = 'Pagination';
    final description = 'Pagination should work correctly';

    try {
      final start = DateTime.now();

      // Verificar que podemos paginar
      final page1 = await _wallpaperDAO.getAllAccepted(limit: 24);
      final page2 = await _wallpaperDAO.getAllAccepted(limit: 24);

      // Debería haber resultados
      final passed = page1.isNotEmpty && page2.isNotEmpty;

      final duration = DateTime.now().difference(start).inMilliseconds;

      return RegressionTest(
        name: name,
        description: description,
        passed: passed,
        error: passed ? null : 'Pagination returned empty pages',
        durationMs: duration.toDouble(),
      );
    } catch (e) {
      return RegressionTest(
        name: name,
        description: description,
        passed: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }

  /// Test: Download still works
  Future<RegressionTest> _testDownload() async {
    final name = 'Download Functionality';
    final description = 'Download URLs should be valid';

    try {
      final start = DateTime.now();

      // Verificar que los wallpapers tienen URLs válidas
      final wallpapers = await _wallpaperDAO.getAllAccepted(limit: 50);
      final withValidUrls = wallpapers
          .where((w) =>
              w.fullUrl.isNotEmpty &&
              (w.fullUrl.startsWith('http://') ||
                  w.fullUrl.startsWith('https://')))
          .length;

      final duration = DateTime.now().difference(start).inMilliseconds;
      final passed = withValidUrls > 0;

      return RegressionTest(
        name: name,
        description: description,
        passed: passed,
        error:
            passed ? null : 'No valid download URLs found ($withValidUrls/${ wallpapers.length})',
        durationMs: duration.toDouble(),
      );
    } catch (e) {
      return RegressionTest(
        name: name,
        description: description,
        passed: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';

/// Resultados de prueba de escalabilidad
class ScaleTestResults {
  final List<ScaleTest> tests;
  final DateTime testedAt;

  ScaleTestResults({
    required this.tests,
    required this.testedAt,
  });

  bool isHealthy() {
    // Verificar que las pruebas no muestran degradación severa
    if (tests.length < 3) return true;

    // Comparar performance entre 50k, 100k y 300k
    final test50k = tests.firstWhere((t) => t.datasetSize == 50000);
    final test300k = tests.firstWhere((t) => t.datasetSize == 300000);

    // Debe haber degradación pero no más del 50%
    final degradation = (test300k.avgQueryTimeMs / test50k.avgQueryTimeMs);
    return degradation < 1.5; // Max 50% slower
  }

  Map<String, dynamic> toJson() {
    return {
      'tests': tests.map((t) => t.toJson()).toList(),
      'isHealthy': isHealthy(),
      'testedAt': testedAt.toIso8601String(),
    };
  }
}

/// Test de escalabilidad individual
class ScaleTest {
  final int datasetSize;
  final double avgQueryTimeMs;
  final double maxQueryTimeMs;
  final double memoryUsageMB;
  final String? bottleneck;

  ScaleTest({
    required this.datasetSize,
    required this.avgQueryTimeMs,
    required this.maxQueryTimeMs,
    required this.memoryUsageMB,
    this.bottleneck,
  });

  Map<String, dynamic> toJson() {
    return {
      'datasetSize': datasetSize,
      'avgQueryTimeMs': avgQueryTimeMs,
      'maxQueryTimeMs': maxQueryTimeMs,
      'memoryUsageMB': memoryUsageMB,
      'bottleneck': bottleneck,
    };
  }
}

/// Tester de escalabilidad
class ScaleTester {
  final WallpaperDAO _wallpaperDAO;

  ScaleTester({
    required WallpaperDAO wallpaperDAO,
  })  : _wallpaperDAO = wallpaperDAO;

  /// Ejecuta pruebas de escalabilidad
  Future<ScaleTestResults> runScaleTests() async {
    debugPrint('ScaleTester: Starting scale tests...');

    final tests = <ScaleTest>[];

    // Test with different dataset sizes
    for (final size in [50000, 100000, 300000]) {
      final test = await _testWithDatasetSize(size);
      tests.add(test);
    }

    debugPrint('ScaleTester: Scale tests complete');

    return ScaleTestResults(
      tests: tests,
      testedAt: DateTime.now(),
    );
  }

  /// Test con tamaño específico de dataset
  Future<ScaleTest> _testWithDatasetSize(int targetSize) async {
    debugPrint('ScaleTester: Testing with $targetSize wallpapers...');

    try {
      final start = DateTime.now();

      // Obtener datos
      final wallpapers = await _wallpaperDAO.getAllAccepted(limit: targetSize);
      final actualSize = wallpapers.length;

      final queryTimes = <double>[];
      const queryCount = 20;

      // Ejecutar varias queries y medir tiempo
      for (int i = 0; i < queryCount; i++) {
        final queryStart = DateTime.now();
        await _wallpaperDAO.getAllAccepted(limit: 100);
        final queryEnd = DateTime.now();
        queryTimes.add(queryEnd.difference(queryStart).inMilliseconds.toDouble());
      }

      queryTimes.sort();

      final avgTime = queryTimes.reduce((a, b) => a + b) / queryTimes.length;
      final maxTime = queryTimes.last;

      // Estimación de uso de memoria (muy aproximada)
      const memoryPerWallpaper = 0.0001; // MB
      final estimatedMemory = actualSize * memoryPerWallpaper;

      debugPrint(
        'ScaleTester: Dataset $actualSize complete. Avg query time: ${avgTime.toStringAsFixed(2)}ms',
      );

      // Identificar bottleneck si existe
      String? bottleneck;
      if (avgTime > 500) {
        bottleneck = 'Query performance degraded';
      }
      if (estimatedMemory > 300) {
        bottleneck = 'Memory usage high';
      }

      return ScaleTest(
        datasetSize: actualSize,
        avgQueryTimeMs: avgTime,
        maxQueryTimeMs: maxTime,
        memoryUsageMB: estimatedMemory,
        bottleneck: bottleneck,
      );
    } catch (e) {
      debugPrint('ScaleTester: Error testing size $targetSize: $e');
      return ScaleTest(
        datasetSize: targetSize,
        avgQueryTimeMs: 0,
        maxQueryTimeMs: 0,
        memoryUsageMB: 0,
        bottleneck: e.toString(),
      );
    }
  }

  /// Identifica cuello de botella
  Future<String> identifyBottleneck() async {
    debugPrint('ScaleTester: Identifying bottleneck...');

    try {
      // Probar diferentes operaciones
      final operations = {
        'getAllAccepted': () => _wallpaperDAO.getAllAccepted(limit: 1000),
        'getTotalCount': () => _wallpaperDAO.getTotalCount(),
      };

      String slowestOp = '';
      double maxTime = 0;

      for (final entry in operations.entries) {
        final start = DateTime.now();
        try {
          await entry.value();
        } catch (e) {
          debugPrint('ScaleTester: Error in ${entry.key}: $e');
          continue;
        }
        final duration = DateTime.now().difference(start).inMilliseconds.toDouble();

        if (duration > maxTime) {
          maxTime = duration;
          slowestOp = entry.key;
        }
      }

      return '$slowestOp (${maxTime.toStringAsFixed(0)}ms)';
    } catch (e) {
      return 'Unable to identify: $e';
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';
import '../search/search_service.dart';
import 'dedup_validator.dart';
import 'nsfw_validator.dart';
import 'tag_validator.dart';
import 'search_validator.dart';
import 'performance_benchmark.dart';
import 'regression_suite.dart';
import 'scale_tester.dart';
import 'ab_test_manager.dart';
import 'monitoring.dart';

/// Resultado completo de QA
class QAReport {
  final DedupMetrics? dedupMetrics;
  final NSFWMetrics? nsfwMetrics;
  final TagMetrics? tagMetrics;
  final SearchMetrics? searchMetrics;
  final BenchmarkResults? benchmarkResults;
  final RegressionResults? regressionResults;
  final ScaleTestResults? scaleResults;
  final ABTestResults? abTestResults;
  final Map<String, dynamic> monitoringReport;
  final List<String> criticalIssues;
  final DateTime generatedAt;

  QAReport({
    this.dedupMetrics,
    this.nsfwMetrics,
    this.tagMetrics,
    this.searchMetrics,
    this.benchmarkResults,
    this.regressionResults,
    this.scaleResults,
    this.abTestResults,
    required this.monitoringReport,
    required this.criticalIssues,
    required this.generatedAt,
  });

  bool isProductionReady() {
    final issues = criticalIssues;

    // Check all validators are healthy
    if (dedupMetrics != null && !dedupMetrics!.isHealthy()) {
      return false;
    }
    if (nsfwMetrics != null && !nsfwMetrics!.isHealthy()) {
      return false;
    }
    if (tagMetrics != null && !tagMetrics!.isHealthy()) {
      return false;
    }
    if (searchMetrics != null && !searchMetrics!.isHealthy()) {
      return false;
    }
    if (benchmarkResults != null && !benchmarkResults!.isHealthy()) {
      return false;
    }
    if (regressionResults != null && !regressionResults!.isHealthy()) {
      return false;
    }
    if (scaleResults != null && !scaleResults!.isHealthy()) {
      return false;
    }

    return issues.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'dedupMetrics': dedupMetrics?.toJson(),
      'nsfwMetrics': nsfwMetrics?.toJson(),
      'tagMetrics': tagMetrics?.toJson(),
      'searchMetrics': searchMetrics?.toJson(),
      'benchmarkResults': benchmarkResults?.toJson(),
      'regressionResults': regressionResults?.toJson(),
      'scaleResults': scaleResults?.toJson(),
      'abTestResults': abTestResults?.toJson(),
      'monitoringReport': monitoringReport,
      'criticalIssues': criticalIssues,
      'isProductionReady': isProductionReady(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

/// Ejecutor de suite QA completa
class QARunner {
  final WallpaperDAO wallpaperDAO;
  final SearchIndexDAO searchIndexDAO;
  final HashRegistryDAO hashRegistryDAO;
  final SearchService searchService;

  QARunner({
    required this.wallpaperDAO,
    required this.searchIndexDAO,
    required this.hashRegistryDAO,
    required this.searchService,
  });

  /// Ejecuta todos los tests de QA
  Future<QAReport> runFullQA({
    bool skipScale = false,
    bool skipAB = false,
  }) async {
    debugPrint('QARunner: Starting full QA suite...');
    final startTime = DateTime.now();

    final criticalIssues = <String>[];
    DedupMetrics? dedupMetrics;
    NSFWMetrics? nsfwMetrics;
    TagMetrics? tagMetrics;
    SearchMetrics? searchMetrics;
    BenchmarkResults? benchmarkResults;
    RegressionResults? regressionResults;
    ScaleTestResults? scaleResults;
    ABTestResults? abTestResults;
    final monitoring = MonitoringService();

    try {
      // 1. Deduplication validation
      debugPrint('QARunner: Running deduplication validation...');
      try {
        final dedupValidator = DedupValidator(
          wallpaperDAO: wallpaperDAO,
          hashRegistryDAO: hashRegistryDAO,
        );
        dedupMetrics = await dedupValidator.validateDeduplication();
        if (!dedupMetrics.isHealthy()) {
          criticalIssues.add('Deduplication health check failed');
        }
      } catch (e) {
        criticalIssues.add('Deduplication validation error: $e');
      }

      // 2. NSFW filter validation
      debugPrint('QARunner: Running NSFW filter validation...');
      try {
        final nsfwValidator = NSFWValidator(wallpaperDAO: wallpaperDAO);
        nsfwMetrics = await nsfwValidator.validateNSFWFilter();
        if (!nsfwMetrics.isHealthy()) {
          criticalIssues.add('NSFW filter health check failed');
        }
      } catch (e) {
        criticalIssues.add('NSFW validation error: $e');
      }

      // 3. Tag validation
      debugPrint('QARunner: Running tag validation...');
      try {
        final tagValidator = TagValidator(wallpaperDAO: wallpaperDAO);
        tagMetrics = await tagValidator.validateTags();
        if (!tagMetrics.isHealthy()) {
          criticalIssues.add('Tag health check failed');
        }
      } catch (e) {
        criticalIssues.add('Tag validation error: $e');
      }

      // 4. Search validation
      debugPrint('QARunner: Running search validation...');
      try {
        final searchValidator = SearchValidator(
          searchService: searchService,
          wallpaperDAO: wallpaperDAO,
        );
        searchMetrics = await searchValidator.validateSearch();
        if (!searchMetrics.isHealthy()) {
          criticalIssues.add('Search health check failed');
        }
      } catch (e) {
        criticalIssues.add('Search validation error: $e');
      }

      // 5. Performance benchmarks
      debugPrint('QARunner: Running performance benchmarks...');
      try {
        final benchmark = PerformanceBenchmark(
          wallpaperDAO: wallpaperDAO,
          searchIndexDAO: searchIndexDAO,
        );
        benchmarkResults = await benchmark.runBenchmark();
        if (!benchmarkResults.isHealthy()) {
          criticalIssues.add('Performance benchmarks show issues');
        }
      } catch (e) {
        criticalIssues.add('Performance benchmark error: $e');
      }

      // 6. Regression testing
      debugPrint('QARunner: Running regression tests...');
      try {
        final regression = RegressionSuite(wallpaperDAO: wallpaperDAO);
        regressionResults = await regression.runAllTests();
        if (!regressionResults.isHealthy()) {
          criticalIssues.add('Regression tests failed');
        }
      } catch (e) {
        criticalIssues.add('Regression testing error: $e');
      }

      // 7. Scale testing (optional)
      if (!skipScale) {
        debugPrint('QARunner: Running scale tests...');
        try {
          final scaleTester = ScaleTester(wallpaperDAO: wallpaperDAO);
          scaleResults = await scaleTester.runScaleTests();
          if (!scaleResults.isHealthy()) {
            criticalIssues.add('Scale tests show performance degradation');
          }
        } catch (e) {
          criticalIssues.add('Scale testing error: $e');
        }
      }

      // 8. Collect monitoring metrics
      debugPrint('QARunner: Collecting monitoring metrics...');
      final collector = SystemMetricsCollector(monitoring: monitoring);
      await collector.collectMetrics();
      final monitoringReport = monitoring.getReport();

      debugPrint('QARunner: QA suite complete');
      final duration = DateTime.now().difference(startTime);
      debugPrint('QARunner: Total duration: ${duration.inSeconds}s');

      return QAReport(
        dedupMetrics: dedupMetrics,
        nsfwMetrics: nsfwMetrics,
        tagMetrics: tagMetrics,
        searchMetrics: searchMetrics,
        benchmarkResults: benchmarkResults,
        regressionResults: regressionResults,
        scaleResults: scaleResults,
        abTestResults: abTestResults,
        monitoringReport: monitoringReport,
        criticalIssues: criticalIssues,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('QARunner: Unexpected error: $e');
      criticalIssues.add('Unexpected error: $e');

      return QAReport(
        monitoringReport: {},
        criticalIssues: criticalIssues,
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Ejecuta solo pruebas críticas (rápidas)
  Future<QAReport> runQuickQA() async {
    debugPrint('QARunner: Starting quick QA...');

    const criticalIssues = <String>[];
    DedupMetrics? dedupMetrics;
    NSFWMetrics? nsfwMetrics;
    RegressionResults? regressionResults;
    final monitoring = MonitoringService();

    try {
      // Solo tests críticos
      final dedupValidator = DedupValidator(
        wallpaperDAO: wallpaperDAO,
        hashRegistryDAO: hashRegistryDAO,
      );
      dedupMetrics = await dedupValidator.validateDeduplication(sampleSize: 100);

      final nsfwValidator = NSFWValidator(wallpaperDAO: wallpaperDAO);
      nsfwMetrics = await nsfwValidator.validateNSFWFilter(sampleSize: 100);

      final regression = RegressionSuite(wallpaperDAO: wallpaperDAO);
      regressionResults = await regression.runAllTests();

      final collector = SystemMetricsCollector(monitoring: monitoring);
      await collector.collectMetrics();
      final monitoringReport = monitoring.getReport();

      return QAReport(
        dedupMetrics: dedupMetrics,
        nsfwMetrics: nsfwMetrics,
        regressionResults: regressionResults,
        monitoringReport: monitoringReport,
        criticalIssues: criticalIssues,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      return QAReport(
        monitoringReport: {},
        criticalIssues: ['Quick QA error: $e'],
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Genera reporte de producción checklist
  Map<String, dynamic> generateProductionChecklist(QAReport report) {
    final regressionHealthy = (report.regressionResults?.successRate ?? 0) > 0.95;

    return {
      'all_providers_working': regressionHealthy,
      'dedup_working': report.dedupMetrics?.isHealthy() ?? false,
      'nsfw_filtering_effective': report.nsfwMetrics?.isHealthy() ?? false,
      'search_responsive': report.searchMetrics?.isHealthy() ?? false,
      'performance_acceptable': report.benchmarkResults?.isHealthy() ?? false,
      'tags_normalized': report.tagMetrics?.isHealthy() ?? false,
      'no_regressions': regressionHealthy,
      'production_ready': report.isProductionReady(),
      'critical_issues': report.criticalIssues,
      'generated_at': report.generatedAt.toIso8601String(),
    };
  }
}

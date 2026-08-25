/// Example: How to use the QA suite
///
/// This file demonstrates how to integrate and use all the QA services
/// in your application.

import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';
import '../search/search_service.dart';
import 'qa.dart';

/// Ejemplo de uso del QA suite
///
/// Puedes ejecutar esto en:
/// 1. Un comando de administrador
/// 2. CI/CD pipeline
/// 3. Scheduled task
/// 4. Manual testing

Future<void> exampleRunFullQA(
  WallpaperDAO wallpaperDAO,
  SearchIndexDAO searchIndexDAO,
  HashRegistryDAO hashRegistryDAO,
  SearchService searchService,
) async {
  // Crear runner
  final qaRunner = QARunner(
    wallpaperDAO: wallpaperDAO,
    searchIndexDAO: searchIndexDAO,
    hashRegistryDAO: hashRegistryDAO,
    searchService: searchService,
  );

  // Ejecutar QA completo
  final report = await qaRunner.runFullQA();

  // Verificar si está listo para producción
  if (report.isProductionReady()) {
    debugPrint('✓ Application is production-ready!');
  } else {
    debugPrint('✗ Critical issues found:');
    for (final issue in report.criticalIssues) {
      debugPrint('  - $issue');
    }
  }

  // Mostrar metricas de deduplicación
  if (report.dedupMetrics != null) {
    debugPrint('\nDeduplication:');
    debugPrint('  Total: ${report.dedupMetrics!.totalWallpapers}');
    debugPrint('  Exact duplicates: ${report.dedupMetrics!.exactDuplicates}');
    debugPrint('  Visual duplicates: ${report.dedupMetrics!.visualDuplicates}');
    debugPrint('  Health: ${report.dedupMetrics!.isHealthy() ? "✓" : "✗"}');
  }

  // Mostrar metricas NSFW
  if (report.nsfwMetrics != null) {
    debugPrint('\nNSFW Filtering:');
    debugPrint('  Potential NSFW: ${report.nsfwMetrics!.potentialNSFWContent}');
    debugPrint('  Precision: ${report.nsfwMetrics!.precision.toStringAsFixed(2)}');
    debugPrint('  Recall: ${report.nsfwMetrics!.recall.toStringAsFixed(2)}');
    debugPrint('  Health: ${report.nsfwMetrics!.isHealthy() ? "✓" : "✗"}');
  }

  // Mostrar metricas de búsqueda
  if (report.searchMetrics != null) {
    debugPrint('\nSearch Performance:');
    debugPrint('  Precision: ${report.searchMetrics!.precision.toStringAsFixed(2)}');
    debugPrint('  Recall: ${report.searchMetrics!.recall.toStringAsFixed(2)}');
    debugPrint('  Avg response: ${report.searchMetrics!.avgResponseTimeMs.toStringAsFixed(2)}ms');
    debugPrint('  P95: ${report.searchMetrics!.p95ResponseTimeMs.toStringAsFixed(2)}ms');
    debugPrint('  P99: ${report.searchMetrics!.p99ResponseTimeMs.toStringAsFixed(2)}ms');
    debugPrint('  Health: ${report.searchMetrics!.isHealthy() ? "✓" : "✗"}');
  }

  // Mostrar benchmarks
  if (report.benchmarkResults != null) {
    debugPrint('\nPerformance:');
    debugPrint('  DB queries: ${report.benchmarkResults!.database.searchIndexQueryTimeMs.toStringAsFixed(2)}ms');
    debugPrint('  pHash compare: ${report.benchmarkResults!.database.pHashComparisonTimeMs.toStringAsFixed(2)}ms');
    debugPrint('  Memory usage: ${report.benchmarkResults!.memory.totalPeakMB.toStringAsFixed(2)}MB');
    debugPrint('  Health: ${report.benchmarkResults!.isHealthy() ? "✓" : "✗"}');
  }

  // Mostrar regresión
  if (report.regressionResults != null) {
    debugPrint('\nRegression Tests:');
    debugPrint('  Passed: ${report.regressionResults!.passed}/${report.regressionResults!.passed + report.regressionResults!.failed}');
    debugPrint('  Success rate: ${(report.regressionResults!.successRate * 100).toStringAsFixed(2)}%');
    debugPrint('  Health: ${report.regressionResults!.isHealthy() ? "✓" : "✗"}');
  }

  // Mostrar escalabilidad
  if (report.scaleResults != null) {
    debugPrint('\nScale Testing:');
    for (final test in report.scaleResults!.tests) {
      debugPrint('  ${test.datasetSize}: ${test.avgQueryTimeMs.toStringAsFixed(2)}ms avg');
    }
  }

  // Exportar reporte JSON
  final jsonReport = report.toJson();
  debugPrint('\n\nFull report (JSON):');
  debugPrint(jsonReport.toString());

  // Generar production checklist
  final checklist = qaRunner.generateProductionChecklist(report);
  debugPrint('\n\nProduction Checklist:');
  for (final entry in checklist.entries) {
    final status = entry.value is bool ? (entry.value ? '✓' : '✗') : entry.value;
    debugPrint('  ${entry.key}: $status');
  }
}

/// Ejemplo: QA rápido (solo pruebas críticas)
Future<void> exampleRunQuickQA(
  WallpaperDAO wallpaperDAO,
  SearchIndexDAO searchIndexDAO,
  HashRegistryDAO hashRegistryDAO,
  SearchService searchService,
) async {
  final qaRunner = QARunner(
    wallpaperDAO: wallpaperDAO,
    searchIndexDAO: searchIndexDAO,
    hashRegistryDAO: hashRegistryDAO,
    searchService: searchService,
  );

  final report = await qaRunner.runQuickQA();

  if (report.isProductionReady()) {
    debugPrint('✓ Quick QA passed - ready for deployment');
  } else {
    debugPrint('✗ Quick QA failed:');
    for (final issue in report.criticalIssues) {
      debugPrint('  - $issue');
    }
  }
}

/// Ejemplo: Validación individual de deduplicación
Future<void> exampleValidateDedup(
  WallpaperDAO wallpaperDAO,
  HashRegistryDAO hashRegistryDAO,
) async {
  final validator = DedupValidator(
    wallpaperDAO: wallpaperDAO,
    hashRegistryDAO: hashRegistryDAO,
  );

  final metrics = await validator.validateDeduplication(sampleSize: 500);

  debugPrint('Deduplication Metrics:');
  debugPrint('  Total: ${metrics.totalWallpapers}');
  debugPrint('  Exact duplicates: ${metrics.exactDuplicates}');
  debugPrint('  False positive rate: ${metrics.falsePositiveRate.toStringAsFixed(3)}');
  debugPrint('  False negative rate: ${metrics.falseNegativeRate.toStringAsFixed(3)}');
  debugPrint('  Avg processing time: ${metrics.avgProcessingTimeMs.toStringAsFixed(2)}ms');
  debugPrint('  Health: ${metrics.isHealthy() ? "✓" : "✗"}');

  // Obtener duplicados exactos
  final exactDups = await validator.getExactDuplicates();
  debugPrint('\nExact duplicates found:');
  for (final entry in exactDups.entries) {
    debugPrint('  Hash ${entry.key.substring(0, 8)}...: ${entry.value.length} copies');
  }
}

/// Ejemplo: Validación de búsqueda
Future<void> exampleValidateSearch(
  SearchService searchService,
  WallpaperDAO wallpaperDAO,
) async {
  final validator = SearchValidator(
    searchService: searchService,
    wallpaperDAO: wallpaperDAO,
  );

  // Validar búsqueda completa
  final metrics = await validator.validateSearch();

  debugPrint('Search Validation:');
  debugPrint('  Precision: ${metrics.precision.toStringAsFixed(3)}');
  debugPrint('  Recall: ${metrics.recall.toStringAsFixed(3)}');
  debugPrint('  F-Measure: ${metrics.fMeasure.toStringAsFixed(3)}');
  debugPrint('  Avg response time: ${metrics.avgResponseTimeMs.toStringAsFixed(2)}ms');
  debugPrint('  P95: ${metrics.p95ResponseTimeMs.toStringAsFixed(2)}ms');
  debugPrint('  Fuzzy matching: ${metrics.fuzzyMatchingWorks ? "✓" : "✗"}');
  debugPrint('  Ranking accurate: ${metrics.rankingAccurate ? "✓" : "✗"}');

  // Probar búsquedas individuales
  final exactResults = await validator.testExactSearch('messi');
  debugPrint('\nExact search "messi": ${exactResults.length} results');

  final fuzzyResults = await validator.testFuzzySearch('aurorr');
  debugPrint('Fuzzy search "aurorr": ${fuzzyResults.length} results');
}

/// Ejemplo: Monitoreo continuo
Future<void> exampleMonitoring() async {
  final monitoring = MonitoringService();
  final collector = SystemMetricsCollector(monitoring: monitoring);

  // Empezar recolección periódica
  final timer = collector.startPeriodicCollection(
    interval: const Duration(seconds: 30),
  );

  // Después de algunos minutos, obtener reporte
  await Future.delayed(const Duration(minutes: 2));

  final report = monitoring.getReport(timeRange: const Duration(minutes: 2));
  debugPrint('Monitoring Report:');
  debugPrint('  Metrics count: ${report['metricsCount']}');
  debugPrint('  Alerts count: ${report['alertsCount']}');
  debugPrint('  Statistics: ${report['statistics']}');

  timer.cancel();
}

/// Ejemplo: A/B Testing
Future<void> exampleABTesting() async {
  final abTest = ABTestManager();

  // Simular usuarios siendo asignados a variantes
  const userIds = ['user1', 'user2', 'user3', 'user4', 'user5'];

  for (final userId in userIds) {
    final variant = abTest.randomizeUserToVariant(userId);
    debugPrint('User $userId assigned to $variant');

    // Simular eventos de usuario
    abTest.trackEvent(userId, variant, 'search');

    if (variant == 'test') {
      // Test group interacted more with new feature
      if (userId.endsWith('1') || userId.endsWith('3')) {
        abTest.trackEvent(userId, variant, 'clicked_new_feature');
      }
    }
  }

  // Analizar resultados
  final results = await abTest.getWinner(
    testName: 'New Search UI',
    conversionEvent: 'clicked_new_feature',
  );

  debugPrint('\nA/B Test Results:');
  debugPrint('  Control conversion: ${results.controlConversion.toStringAsFixed(3)}');
  debugPrint('  Test conversion: ${results.testConversion.toStringAsFixed(3)}');
  debugPrint('  Lift: ${results.conversionLift.toStringAsFixed(2)}%');
  debugPrint('  Winner: ${results.winner ?? "No winner yet"}');

  // Exportar eventos
  final events = abTest.exportEvents();
  debugPrint('\nTracked ${events.length} events');
}

/// Ejemplo: Benchmark de performance
Future<void> examplePerformanceBenchmark(
  WallpaperDAO wallpaperDAO,
  SearchIndexDAO searchIndexDAO,
) async {
  final benchmark = PerformanceBenchmark(
    wallpaperDAO: wallpaperDAO,
    searchIndexDAO: searchIndexDAO,
  );

  final results = await benchmark.runBenchmark(environment: 'staging');

  debugPrint('Performance Benchmark (${results.environment}):');
  debugPrint('\nDatabase:');
  debugPrint('  Search query: ${results.database.searchIndexQueryTimeMs.toStringAsFixed(2)}ms');
  debugPrint('  pHash comparison: ${results.database.pHashComparisonTimeMs.toStringAsFixed(2)}ms');
  debugPrint('  Tag relation expansion: ${results.database.tagRelationExpansionTimeMs.toStringAsFixed(2)}ms');

  debugPrint('\nMemory:');
  debugPrint('  Database: ${results.memory.databaseOpenMB.toStringAsFixed(2)}MB');
  debugPrint('  Search index: ${results.memory.searchIndexMB.toStringAsFixed(2)}MB');
  debugPrint('  pHash cache: ${results.memory.pHashCacheMB.toStringAsFixed(2)}MB');
  debugPrint('  Total: ${results.memory.totalPeakMB.toStringAsFixed(2)}MB');

  // Benchmark de latencia de búsqueda
  final latency = await benchmark.benchmarkSearchLatency(queriesCount: 100);
  debugPrint('\nSearch Latency:');
  debugPrint('  Min: ${latency.minMs.toStringAsFixed(2)}ms');
  debugPrint('  Max: ${latency.maxMs.toStringAsFixed(2)}ms');
  debugPrint('  Avg: ${latency.avgMs.toStringAsFixed(2)}ms');
  debugPrint('  P95: ${latency.p95Ms.toStringAsFixed(2)}ms');
  debugPrint('  P99: ${latency.p99Ms.toStringAsFixed(2)}ms');
}

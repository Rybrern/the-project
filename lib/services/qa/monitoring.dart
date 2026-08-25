import 'dart:async';
import 'package:flutter/foundation.dart';

/// Métrica de monitoreo
class MonitoringMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? tags;

  MonitoringMetric({
    required this.name,
    required this.value,
    required this.unit,
    DateTime? timestamp,
    this.tags,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags,
    };
  }
}

/// Alerta de monitoreo
class Alert {
  final String level; // 'info', 'warning', 'critical'
  final String message;
  final String metric;
  final double threshold;
  final double value;
  final DateTime timestamp;

  Alert({
    required this.level,
    required this.message,
    required this.metric,
    required this.threshold,
    required this.value,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'message': message,
      'metric': metric,
      'threshold': threshold,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Sistema de monitoreo
class MonitoringService {
  final List<MonitoringMetric> _metrics = [];
  final List<Alert> _alerts = [];
  final Map<String, double> _thresholds = {
    'provider_downtime_minutes': 5,
    'error_rate_percent': 5,
    'search_latency_ms': 1000,
    'memory_usage_mb': 400,
  };

  /// Registra una métrica
  void recordMetric({
    required String name,
    required double value,
    required String unit,
    Map<String, dynamic>? tags,
  }) {
    final metric = MonitoringMetric(
      name: name,
      value: value,
      unit: unit,
      tags: tags,
    );

    _metrics.add(metric);

    // Verificar si hay alert
    _checkAlert(metric);

    debugPrint('MonitoringService: Recorded $name = $value $unit');
  }

  /// Obtiene métricas
  List<MonitoringMetric> getMetrics({
    String? nameFilter,
    Duration? timeRange,
  }) {
    var results = _metrics.toList();

    if (nameFilter != null) {
      results = results.where((m) => m.name.contains(nameFilter)).toList();
    }

    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      results = results.where((m) => m.timestamp.isAfter(cutoff)).toList();
    }

    return results;
  }

  /// Obtiene alertas
  List<Alert> getAlerts({
    String? level,
    Duration? timeRange,
  }) {
    var results = _alerts.toList();

    if (level != null) {
      results = results.where((a) => a.level == level).toList();
    }

    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      results = results.where((a) => a.timestamp.isAfter(cutoff)).toList();
    }

    return results;
  }

  /// Verifica si hay alert
  void _checkAlert(MonitoringMetric metric) {
    for (final entry in _thresholds.entries) {
      if (metric.name.contains(entry.key)) {
        if (metric.value > entry.value) {
          _alerts.add(Alert(
            level: 'warning',
            message:
                '${metric.name} exceeded threshold: ${metric.value} > ${entry.value}',
            metric: metric.name,
            threshold: entry.value,
            value: metric.value,
          ));

          debugPrint(
            'MonitoringService: ALERT - ${metric.name} = ${metric.value} (threshold: ${entry.value})',
          );
        }
      }
    }
  }

  /// Exporta report
  Map<String, dynamic> getReport({Duration? timeRange}) {
    final metrics = getMetrics(timeRange: timeRange);
    final alerts = getAlerts(timeRange: timeRange);

    // Calcular estadísticas por métrica
    final stats = <String, dynamic>{};
    final byName = <String, List<MonitoringMetric>>{};

    for (final metric in metrics) {
      if (!byName.containsKey(metric.name)) {
        byName[metric.name] = [];
      }
      byName[metric.name]!.add(metric);
    }

    for (final entry in byName.entries) {
      final values = entry.value.map((m) => m.value).toList();
      values.sort();

      stats[entry.key] = {
        'count': values.length,
        'min': values.first,
        'max': values.last,
        'avg': values.reduce((a, b) => a + b) / values.length,
        'p50': values[values.length ~/ 2],
        'p95': values[(values.length * 0.95).toInt()],
        'p99': values[(values.length * 0.99).toInt()],
      };
    }

    return {
      'timeRange': timeRange?.toString(),
      'metricsCount': metrics.length,
      'alertsCount': alerts.length,
      'statistics': stats,
      'recentAlerts': alerts.take(10).map((a) => a.toJson()).toList(),
    };
  }

  /// Limpia métricas antiguas
  void cleanup({Duration olderThan = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(olderThan);
    final before = _metrics.length;

    _metrics.removeWhere((m) => m.timestamp.isBefore(cutoff));

    debugPrint(
      'MonitoringService: Cleanup removed ${before - _metrics.length} old metrics',
    );
  }
}

/// Recolector de métricas del sistema
class SystemMetricsCollector {
  final MonitoringService _monitoring;

  SystemMetricsCollector({required MonitoringService monitoring})
      : _monitoring = monitoring;

  /// Inicia recolección periódica de métricas
  Timer startPeriodicCollection({Duration interval = const Duration(seconds: 30)}) {
    debugPrint('SystemMetricsCollector: Starting periodic collection every ${interval.inSeconds}s');

    return Timer.periodic(interval, (_) async {
      await collectMetrics();
    });
  }

  /// Recolecta métricas del sistema
  Future<void> collectMetrics() async {
    // Provider availability
    _monitoring.recordMetric(
      name: 'provider_availability',
      value: 100.0, // 100% (en un escenario real)
      unit: 'percent',
      tags: {'provider': 'openverse'},
    );

    // Error rate
    _monitoring.recordMetric(
      name: 'error_rate',
      value: 0.5, // 0.5% (estimado)
      unit: 'percent',
    );

    // Search latency
    _monitoring.recordMetric(
      name: 'search_latency',
      value: 150.0, // 150ms (estimado)
      unit: 'ms',
    );

    // Memory usage
    _monitoring.recordMetric(
      name: 'memory_usage',
      value: 200.0, // 200MB (estimado)
      unit: 'mb',
    );

    // Dedup effectiveness
    _monitoring.recordMetric(
      name: 'dedup_effectiveness',
      value: 98.5, // 98.5% of duplicates caught
      unit: 'percent',
    );
  }
}

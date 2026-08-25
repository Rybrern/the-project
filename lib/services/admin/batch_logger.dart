import 'package:flutter/foundation.dart';
import '../batch_processing/batch_models.dart';

/// Sistema de logging para batch processing.
/// Registra todo lo que sucede durante ingesta masiva.
class BatchLogger {
  final StringBuffer _buffer = StringBuffer();
  final List<String> _logs = [];
  final int maxLogLines;

  BatchLogger({this.maxLogLines = 10000});

  /// Agrega un log
  void log(String message, {String level = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$level] $message';

    _logs.add(logEntry);
    _buffer.writeln(logEntry);

    // Limita tamaño
    if (_logs.length > maxLogLines) {
      _logs.removeAt(0);
    }

    // En debug, también imprime
    if (kDebugMode) {
      debugPrint(logEntry);
    }
  }

  /// Log de info
  void info(String message) => log(message, level: 'INFO');

  /// Log de warning
  void warn(String message) => log(message, level: 'WARN');

  /// Log de error
  void error(String message) => log(message, level: 'ERROR');

  /// Log de debug
  void debug(String message) => log(message, level: 'DEBUG');

  /// Log de progreso
  void progress(String stage, int current, int total) {
    final percent = total == 0 ? 0 : ((current / total) * 100).toStringAsFixed(1);
    log('$stage: $current/$total ($percent%)', level: 'PROGRESS');
  }

  /// Obtiene todos los logs
  List<String> getLogs() => List.unmodifiable(_logs);

  /// Obtiene logs como string
  String getLogsAsString() => _buffer.toString();

  /// Obtiene últimos N logs
  List<String> getRecentLogs({int lines = 100}) {
    final start = (_logs.length - lines).clamp(0, _logs.length);
    return _logs.sublist(start);
  }

  /// Limpia todos los logs
  void clear() {
    _logs.clear();
    _buffer.clear();
  }

  /// Exporta logs a archivo
  String exportAsText() {
    return _buffer.toString();
  }

  /// Exporta como JSON para análisis
  String exportAsJSON() {
    final entries = _logs.map((log) {
      final parts = log.split('] [');
      if (parts.length >= 3) {
        return {
          'timestamp': parts[0].replaceFirst('[', ''),
          'level': parts[1],
          'message': parts.sublist(2).join('] [').replaceFirst(' ', ''),
        };
      }
      return {'raw': log};
    }).toList();

    return entries.toString(); // Idealmente usar jsonEncode
  }

  /// Estadísticas de logs
  Map<String, int> getStatistics() {
    final stats = <String, int>{
      'total': _logs.length,
      'INFO': 0,
      'WARN': 0,
      'ERROR': 0,
      'DEBUG': 0,
      'PROGRESS': 0,
    };

    for (final log in _logs) {
      for (final level in stats.keys) {
        if (log.contains('[$level]')) {
          stats[level] = (stats[level] ?? 0) + 1;
        }
      }
    }

    return stats;
  }
}

/// Logger formateado para batch jobs
class BatchJobLogger {
  BatchJobLogger(this.jobId) : logger = BatchLogger();

  final String jobId;
  final BatchLogger logger;
  final DateTime startTime = DateTime.now();

  /// Log con prefijo de job
  void log(String message, {String level = 'INFO'}) {
    logger.log('[Job $jobId] $message', level: level);
  }

  /// Genera reporte del job
  String generateReport(BatchReport report) {
    final buffer = StringBuffer();
    buffer.writeln('=== BATCH JOB REPORT ===');
    buffer.writeln('Job ID: $jobId');
    buffer.writeln('Start Time: ${report.startTime}');
    buffer.writeln('End Time: ${report.endTime}');
    buffer.writeln('Duration: ${report.duration.inSeconds}s');
    buffer.writeln('');
    buffer.writeln('STATISTICS:');
    buffer.writeln('  Total Candidates: ${report.totalCandidates}');
    buffer.writeln('  Accepted: ${report.acceptedCount}');
    buffer.writeln('  Rejected: ${report.rejectedCount}');
    buffer.writeln('  Errors: ${report.errorCount}');
    buffer.writeln('  Acceptance Rate: ${(report.acceptanceRate * 100).toStringAsFixed(2)}%');
    buffer.writeln('  Error Rate: ${(report.errorRate * 100).toStringAsFixed(2)}%');
    buffer.writeln('  Speed: ${report.itemsPerSecond.toStringAsFixed(2)} items/s');
    buffer.writeln('');
    buffer.writeln('REJECTION SUMMARY:');
    final rejectionSummary = report.getRejectionSummary();
    for (final entry in rejectionSummary.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    buffer.writeln('');
    buffer.writeln('LOGS:');
    buffer.writeln(logger.getLogsAsString());
    buffer.writeln('======================');

    return buffer.toString();
  }
}

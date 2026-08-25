import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';

/// Exporta datos para análisis externo.
class DataExporter {
  DataExporter({
    required this.wallpaperDAO,
    required this.processingRecordDAO,
    required this.rejectedCandidateDAO,
  });

  final WallpaperDAO wallpaperDAO;
  final ProcessingRecordDAO processingRecordDAO;
  final RejectedCandidateDAO rejectedCandidateDAO;

  /// Exporta wallpapers como JSON
  Future<String> exportWallpapersAsJSON({int limit = 10000}) async {
    debugPrint('DataExporter: Exporting wallpapers as JSON');
    final wallpapers = await wallpaperDAO.getAllAccepted(limit: limit);

    final data = wallpapers.map((w) => {
      'id': w.id,
      'source': w.source,
      'category': w.primaryCategory,
      'subcategory': w.subcategory,
      'aspect_ratio': w.aspectRatio,
      'nsfw_score': w.nsfwScore,
      'quality_score': w.qualityScore,
      'tags': w.tags,
      'source_url': w.originalUrl,
    }).toList();

    return _toJSON(data);
  }

  /// Exporta como CSV
  Future<String> exportWallpapersAsCSV({int limit = 10000}) async {
    debugPrint('DataExporter: Exporting wallpapers as CSV');
    final wallpapers = await wallpaperDAO.getAllAccepted(limit: limit);

    final buffer = StringBuffer();
    buffer.writeln('id,source,category,subcategory,aspect_ratio,nsfw_score,quality_score,tags,url');

    for (final w in wallpapers) {
      final tags = (w.tags ?? []).join(';');
      buffer.writeln('${w.id},"${w.source}","${w.primaryCategory}","${w.subcategory}",'
          '${w.aspectRatio},${w.nsfwScore},${w.qualityScore},"$tags","${w.originalUrl}"');
    }

    return buffer.toString();
  }

  /// Exporta estadísticas de procesamiento
  Future<String> exportProcessingStats() async {
    debugPrint('DataExporter: Exporting processing statistics');

    final stats = await processingRecordDAO.getStatistics();
    final rejections = await rejectedCandidateDAO.getRejectionStats();
    final rateBySource = await rejectedCandidateDAO.getRejectionRateBySource();

    return _toJSON({
      'processing': stats,
      'rejections': rejections,
      'rate_by_source': rateBySource,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Exporta datos para análisis de Machine Learning
  Future<String> exportForML() async {
    debugPrint('DataExporter: Exporting data for ML analysis');

    final wallpapers = await wallpaperDAO.getAllAccepted();
    final rejected = await rejectedCandidateDAO.getRecentRejections(limit: 5000);

    final dataset = {
      'accepted': wallpapers.map((w) => {
        'id': w.id,
        'nsfw_score': w.nsfwScore,
        'quality_score': w.qualityScore,
        'aspect_ratio': w.aspectRatio,
        'source': w.source,
        'category': w.primaryCategory,
        'label': 1, // accepted
      }).toList(),
      'rejected': rejected.map((r) => {
        'id': r['id'],
        'reason': r['rejection_reason'],
        'source': r['source_id'],
        'label': 0, // rejected
      }).toList(),
    };

    return _toJSON(dataset);
  }

  /// Exporta reporte completo de ingesta
  Future<String> generateFullReport() async {
    debugPrint('DataExporter: Generating full ingestion report');

    final totalWallpapers = await wallpaperDAO.getTotalCount();
    final processingStats = await processingRecordDAO.getStatistics();
    final rejectionStats = await rejectedCandidateDAO.getRejectionStats();
    final commonRejections = await rejectedCandidateDAO.getMostCommonRejections(limit: 10);

    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'summary': {
        'total_wallpapers': totalWallpapers,
        'processing_stats': processingStats,
        'rejection_summary': rejectionStats,
      },
      'top_rejection_reasons': commonRejections,
      'quality_metrics': {
        'avg_nsfw_score': _calculateAverage(
          await wallpaperDAO.getAllAccepted(),
          (w) => w.nsfwScore ?? 0,
        ),
        'avg_quality_score': _calculateAverage(
          await wallpaperDAO.getAllAccepted(),
          (w) => w.qualityScore ?? 0,
        ),
      },
    };

    return _toJSON(report);
  }

  /// Exporta datos de análisis temporal
  Future<String> exportTemporalAnalysis() async {
    debugPrint('DataExporter: Exporting temporal analysis');

    final records = await processingRecordDAO.getRecentRecords(limit: 10000);

    // Agrupa por día
    final byDate = <String, Map<String, int>>{};
    for (final record in records) {
      final date = record.processedAt;
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      byDate[dateKey] ??= {'processed': 0, 'accepted': 0, 'rejected': 0};
      byDate[dateKey]!['processed'] = (byDate[dateKey]!['processed'] ?? 0) + 1;

      if (record.status == 'processed') {
        byDate[dateKey]!['accepted'] = (byDate[dateKey]!['accepted'] ?? 0) + 1;
      } else {
        byDate[dateKey]!['rejected'] = (byDate[dateKey]!['rejected'] ?? 0) + 1;
      }
    }

    return _toJSON({
      'by_date': byDate,
      'period': {
        'from': records.isEmpty ? null : records.last.processedAt.toIso8601String(),
        'to': records.isEmpty ? null : records.first.processedAt.toIso8601String(),
      },
    });
  }

  /// Calcula promedio de una propiedad
  double _calculateAverage<T>(List<T> items, double Function(T) selector) {
    if (items.isEmpty) return 0.0;
    final sum = items.fold(0.0, (a, b) => a + selector(b));
    return sum / items.length;
  }

  /// Convierte a JSON con indentación
  String _toJSON(dynamic data) {
    return jsonEncode(data);
  }
}

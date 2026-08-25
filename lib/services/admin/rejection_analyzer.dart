import '../../database/daos/daos.dart';

/// Analiza patrones de rechazo para mejorar el sistema.
class RejectionAnalyzer {
  RejectionAnalyzer({required this.rejectedCandidateDAO});

  final RejectedCandidateDAO rejectedCandidateDAO;

  /// Obtiene análisis completo de rechazos
  Future<Map<String, dynamic>> analyzeRejections() async {
    final stats = await rejectedCandidateDAO.getRejectionStats();
    final rateBySource = await rejectedCandidateDAO.getRejectionRateBySource();
    final commonReasons = await rejectedCandidateDAO.getMostCommonRejections();

    return {
      'rejection_counts': stats,
      'total_rejected': stats.values.fold(0, (a, b) => a + b),
      'most_common_reasons': commonReasons,
      'rejection_rate_by_source': rateBySource,
      'summary': _generateSummary(stats, commonReasons),
    };
  }

  /// Obtiene recomendaciones basadas en análisis
  Future<List<String>> getRecommendations() async {
    final analysis = await analyzeRejections();
    final recommendations = <String>[];

    final stats = analysis['rejection_counts'] as Map<String, int>;
    final total = analysis['total_rejected'] as int;

    // Analiza patrones
    final duplicateRate = ((stats['duplicate'] ?? 0) / (total == 0 ? 1 : total) * 100);
    if (duplicateRate > 30) {
      recommendations.add('High duplicate rate ($duplicateRate%). Consider improving dedup hashing.');
    }

    final nsfwRate = ((stats['nsfw'] ?? 0) / (total == 0 ? 1 : total) * 100);
    if (nsfwRate > 40) {
      recommendations.add('High NSFW rejection rate ($nsfwRate%). Consider adjusting thresholds.');
    }

    final qualityRate = ((stats['quality'] ?? 0) / (total == 0 ? 1 : total) * 100);
    if (qualityRate > 50) {
      recommendations.add('High quality rejection rate ($qualityRate%). Sources may have low resolution.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('System performing well. Continue monitoring.');
    }

    return recommendations;
  }

  /// Genera resumen textual
  String _generateSummary(Map<String, int> stats, List<Map<String, dynamic>> commonReasons) {
    final buffer = StringBuffer();
    buffer.writeln('=== REJECTION ANALYSIS ===');
    buffer.writeln('');
    buffer.writeln('Counts by Reason:');
    for (final entry in stats.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    buffer.writeln('');
    buffer.writeln('Top Rejection Reasons:');
    for (var i = 0; i < commonReasons.take(5).length; i++) {
      final reason = commonReasons[i]['rejection_reason'] ?? 'unknown';
      final count = commonReasons[i]['count'] ?? 0;
      buffer.writeln('  ${i + 1}. $reason: $count');
    }

    return buffer.toString();
  }

  /// Obtiene tendencias temporales de rechazos
  Future<Map<String, dynamic>> getTemporalTrends() async {
    final recentRejections = await rejectedCandidateDAO.getRecentRejections(limit: 1000);

    // Agrupa por día
    final byDate = <String, int>{};
    for (final rejection in recentRejections) {
      if (rejection['processed_at'] != null) {
        final timestamp = rejection['processed_at'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        byDate[dateKey] = (byDate[dateKey] ?? 0) + 1;
      }
    }

    return {
      'rejections_by_date': byDate,
      'total_in_sample': recentRejections.length,
    };
  }
}

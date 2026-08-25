import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import 'dart:convert';

class RejectedCandidateDAO {
  final AppDatabase _appDatabase;

  RejectedCandidateDAO(this._appDatabase);

  /// Registra un candidato rechazado
  Future<void> insert({
    required String id,
    required String sourceUrl,
    required String rejectionReason,
    String? sourceId,
    Map<String, dynamic>? rejectionDetails,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'rejected_candidates',
      {
        'id': id,
        'source_url': sourceUrl,
        'source_id': sourceId,
        'rejection_reason': rejectionReason,
        'rejection_details': rejectionDetails != null ? jsonEncode(rejectionDetails) : null,
        'processed_at': now,
        'created_at': now,
      },
    );
  }

  /// Obtiene todos los rechazos por motivo
  Future<List<Map<String, dynamic>>> getByReason(String reason, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'rejected_candidates',
      where: 'rejection_reason = ?',
      whereArgs: [reason],
      orderBy: 'processed_at DESC',
      limit: limit,
    );
    return maps;
  }

  /// Obtiene estadísticas de rechazos (counts por motivo)
  Future<Map<String, int>> getRejectionStats() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery(
      '''SELECT rejection_reason, COUNT(*) as count
         FROM rejected_candidates
         GROUP BY rejection_reason
         ORDER BY count DESC''',
    );

    final stats = <String, int>{};
    for (final row in results) {
      stats[row['rejection_reason'] as String] = (row['count'] as int?) ?? 0;
    }
    return stats;
  }

  /// Obtiene el total de candidatos rechazados
  Future<int> getTotalCount() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM rejected_candidates');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Obtiene rechazos recientes para análisis
  Future<List<Map<String, dynamic>>> getRecentRejections({int limit = 50}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'rejected_candidates',
      orderBy: 'processed_at DESC',
      limit: limit,
    );
    return maps;
  }

  /// Obtiene detalle de un rechazo específico
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'rejected_candidates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Elimina registros de rechazos anteriores a una fecha
  Future<int> deleteOlderThan(DateTime date) async {
    final db = await _appDatabase.database;
    final timestamp = date.millisecondsSinceEpoch;
    return db.delete(
      'rejected_candidates',
      where: 'processed_at < ?',
      whereArgs: [timestamp],
    );
  }

  /// Análisis: obtiene motivos más comunes de rechazo
  Future<List<Map<String, dynamic>>> getMostCommonRejections({int limit = 10}) async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery(
      '''SELECT rejection_reason, COUNT(*) as count
         FROM rejected_candidates
         GROUP BY rejection_reason
         ORDER BY count DESC
         LIMIT ?''',
      [limit],
    );
    return results;
  }

  /// Análisis: tasa de rechazo por fuente
  Future<Map<String, Map<String, dynamic>>> getRejectionRateBySource() async {
    final db = await _appDatabase.database;

    // Obtiene stats de rechazados por fuente
    final rejectedBySource = await db.rawQuery(
      '''SELECT source_id, COUNT(*) as rejected
         FROM rejected_candidates
         WHERE source_id IS NOT NULL
         GROUP BY source_id''',
    );

    // Obtiene stats de aceptados por fuente
    final acceptedBySource = await db.rawQuery(
      '''SELECT source_id, COUNT(*) as accepted
         FROM processing_records
         WHERE status = 'processed' AND source_id IS NOT NULL
         GROUP BY source_id''',
    );

    final rates = <String, Map<String, dynamic>>{};

    for (final row in rejectedBySource) {
      final sourceId = row['source_id'] as String;
      final rejected = (row['rejected'] as int?) ?? 0;
      rates[sourceId] ??= {'rejected': 0, 'accepted': 0};
      rates[sourceId]!['rejected'] = rejected;
    }

    for (final row in acceptedBySource) {
      final sourceId = row['source_id'] as String;
      final accepted = (row['accepted'] as int?) ?? 0;
      rates[sourceId] ??= {'rejected': 0, 'accepted': 0};
      rates[sourceId]!['accepted'] = accepted;
    }

    // Calcula porcentajes
    for (final entry in rates.entries) {
      final rejected = entry.value['rejected'] as int;
      final accepted = entry.value['accepted'] as int;
      final total = rejected + accepted;
      if (total > 0) {
        entry.value['rejection_rate'] = (rejected / total * 100).toStringAsFixed(2);
      }
    }

    return rates;
  }
}

import 'package:sqflite/sqflite.dart';
import '../../models/processing_record.dart';
import '../app_database.dart';
import 'dart:convert';

class ProcessingRecordDAO {
  final AppDatabase _appDatabase;

  ProcessingRecordDAO(this._appDatabase);

  Future<void> insert(ProcessingRecord record) async {
    final db = await _appDatabase.database;

    await db.insert(
      'processing_records',
      {
        'id': record.id,
        'source_url': record.sourceUrl,
        'source_id': record.sourceId,
        'wallpaper_id': record.wallpaperId,
        'status': record.status,
        'rejection_reason': record.rejectionReason,
        'metadata': record.metadata != null ? jsonEncode(record.metadata) : null,
        'processed_at': record.processedAt.millisecondsSinceEpoch,
        'processing_time_ms': record.processingTimeMs,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<List<ProcessingRecord>> getByStatus(String status, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'processing_records',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'processed_at DESC',
      limit: limit,
    );
    return maps.map(_mapToRecord).toList();
  }

  Future<List<ProcessingRecord>> getBySourceId(String sourceId, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'processing_records',
      where: 'source_id = ?',
      whereArgs: [sourceId],
      limit: limit,
    );
    return maps.map(_mapToRecord).toList();
  }

  Future<List<ProcessingRecord>> getByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'processing_records',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
    );
    return maps.map(_mapToRecord).toList();
  }

  Future<List<ProcessingRecord>> getRecentRecords({int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'processing_records',
      orderBy: 'processed_at DESC',
      limit: limit,
    );
    return maps.map(_mapToRecord).toList();
  }

  Future<int> getCountByStatus(String status) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM processing_records WHERE status = ?',
      [status],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalCount() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM processing_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getStatistics() async {
    final db = await _appDatabase.database;
    final results = await db.rawQuery(
      '''SELECT status, COUNT(*) as count
         FROM processing_records
         GROUP BY status''',
    );

    final stats = <String, int>{};
    for (final row in results) {
      stats[row['status'] as String] = (row['count'] as int?) ?? 0;
    }
    return stats;
  }

  Future<void> delete(String id) async {
    final db = await _appDatabase.database;
    await db.delete('processing_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByStatus(String status) async {
    final db = await _appDatabase.database;
    await db.delete('processing_records', where: 'status = ?', whereArgs: [status]);
  }

  ProcessingRecord _mapToRecord(Map<String, dynamic> map) {
    return ProcessingRecord(
      id: map['id'] as String,
      sourceUrl: map['source_url'] as String,
      sourceId: map['source_id'] as String?,
      wallpaperId: map['wallpaper_id'] as String?,
      status: map['status'] as String,
      rejectionReason: map['rejection_reason'] as String?,
      metadata: map['metadata'] != null ? jsonDecode(map['metadata'] as String) as Map<String, dynamic> : null,
      processedAt: DateTime.fromMillisecondsSinceEpoch(map['processed_at'] as int),
      processingTimeMs: map['processing_time_ms'] as int,
    );
  }
}

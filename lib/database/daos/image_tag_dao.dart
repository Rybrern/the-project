import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Modelo para la asociación imagen-tag
class ImageTag {
  const ImageTag({
    required this.id,
    required this.wallpaperId,
    required this.tagId,
    this.confidence = 0.95,
    this.source,
    required this.createdAt,
  });

  final int id;
  final String wallpaperId;
  final int tagId;
  final double confidence; // 0.0 - 1.0
  final String? source; // "api_metadata", "visual_analysis", "user"
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'wallpaper_id': wallpaperId,
    'tag_id': tagId,
    'confidence': confidence,
    'source': source,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory ImageTag.fromMap(Map<String, dynamic> map) => ImageTag(
    id: map['id'] as int,
    wallpaperId: map['wallpaper_id'] as String,
    tagId: map['tag_id'] as int,
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
    source: map['source'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((map['created_at'] as int?) ?? 0) * 1000,
    ),
  );
}

/// DAO para operaciones con asociaciones imagen-tag
class ImageTagDAO {
  final AppDatabase _appDatabase;

  ImageTagDAO(this._appDatabase);

  /// Inserta una asociación imagen-tag
  Future<int> insert(ImageTag imageTag) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'image_tags',
      imageTag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta múltiples asociaciones en batch
  Future<void> insertBatch(List<ImageTag> imageTags) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final imageTag in imageTags) {
      batch.insert('image_tags', imageTag.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  /// Obtiene un ImageTag por ID
  Future<ImageTag?> getById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query('image_tags', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return ImageTag.fromMap(maps.first);
  }

  /// Obtiene todos los tags para una imagen específica
  Future<List<ImageTag>> getByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'image_tags',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
      orderBy: 'confidence DESC',
    );
    return maps.map((map) => ImageTag.fromMap(map)).toList();
  }

  /// Obtiene todas las imágenes que tienen un tag específico
  Future<List<String>> getWallpapersByTagId(int tagId, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'image_tags',
      columns: ['wallpaper_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
      limit: limit,
      orderBy: 'confidence DESC',
      distinct: true,
    );
    return maps.map((map) => map['wallpaper_id'] as String).toList();
  }

  /// Obtiene imágenes que tienen TODOS los tags especificados
  /// Útil para búsquedas como "Messi AND Argentina"
  Future<List<String>> getWallpapersByTagIds(List<int> tagIds, {int limit = 100}) async {
    if (tagIds.isEmpty) return [];

    final db = await _appDatabase.database;
    final placeholders = tagIds.map((_) => '?').join(',');

    final maps = await db.rawQuery('''
      SELECT DISTINCT it1.wallpaper_id
      FROM image_tags it1
      WHERE it1.tag_id IN ($placeholders)
      GROUP BY it1.wallpaper_id
      HAVING COUNT(DISTINCT it1.tag_id) = ?
      ORDER BY it1.confidence DESC
      LIMIT ?
    ''', [...tagIds, tagIds.length, limit]);

    return maps.map((map) => map['wallpaper_id'] as String).toList();
  }

  /// Obtiene imágenes que tienen CUALQUIERA de los tags especificados
  /// Útil para búsquedas como "Messi OR Ronaldo"
  Future<List<String>> getWallpapersByTagIdsOR(List<int> tagIds, {int limit = 100}) async {
    if (tagIds.isEmpty) return [];

    final db = await _appDatabase.database;
    final placeholders = tagIds.map((_) => '?').join(',');

    final maps = await db.rawQuery('''
      SELECT DISTINCT wallpaper_id
      FROM image_tags
      WHERE tag_id IN ($placeholders)
      ORDER BY confidence DESC
      LIMIT ?
    ''', [...tagIds, limit]);

    return maps.map((map) => map['wallpaper_id'] as String).toList();
  }

  /// Obtiene tags de una imagen con confianza mínima
  /// Útil para filtrar solo tags altamente confiables
  Future<List<ImageTag>> getByWallpaperIdWithMinConfidence(
    String wallpaperId, {
    double minConfidence = 0.8,
  }) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'image_tags',
      where: 'wallpaper_id = ? AND confidence >= ?',
      whereArgs: [wallpaperId, minConfidence],
      orderBy: 'confidence DESC',
    );
    return maps.map((map) => ImageTag.fromMap(map)).toList();
  }

  /// Obtiene tags por fuente (para auditoría de calidad)
  Future<List<ImageTag>> getBySource(String source, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'image_tags',
      where: 'source = ?',
      whereArgs: [source],
      limit: limit,
      orderBy: 'confidence DESC',
    );
    return maps.map((map) => ImageTag.fromMap(map)).toList();
  }

  /// Actualiza un ImageTag (principalmente para cambiar confianza)
  Future<int> update(ImageTag imageTag) async {
    final db = await _appDatabase.database;
    return await db.update(
      'image_tags',
      imageTag.toMap(),
      where: 'id = ?',
      whereArgs: [imageTag.id],
    );
  }

  /// Elimina un ImageTag
  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return await db.delete('image_tags', where: 'id = ?', whereArgs: [id]);
  }

  /// Elimina todos los tags de una imagen (limpieza)
  Future<int> deleteByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    return await db.delete('image_tags', where: 'wallpaper_id = ?', whereArgs: [wallpaperId]);
  }

  /// Elimina todas las asociaciones de un tag (cuando se elimina el tag)
  Future<int> deleteByTagId(int tagId) async {
    final db = await _appDatabase.database;
    return await db.delete('image_tags', where: 'tag_id = ?', whereArgs: [tagId]);
  }

  /// Cuenta total de asociaciones imagen-tag
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM image_tags');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Cuenta tags para una imagen específica
  Future<int> countByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM image_tags WHERE wallpaper_id = ?',
      [wallpaperId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Obtiene estadísticas de tagging
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_associations,
        COUNT(DISTINCT wallpaper_id) as images_with_tags,
        COUNT(DISTINCT tag_id) as unique_tags,
        AVG(confidence) as avg_confidence,
        MIN(confidence) as min_confidence,
        MAX(confidence) as max_confidence
      FROM image_tags
    ''');

    final row = result.first;
    return {
      'total_associations': row['total_associations'],
      'images_with_tags': row['images_with_tags'],
      'unique_tags': row['unique_tags'],
      'avg_confidence': (row['avg_confidence'] as num?)?.toDouble(),
      'min_confidence': (row['min_confidence'] as num?)?.toDouble(),
      'max_confidence': (row['max_confidence'] as num?)?.toDouble(),
    };
  }

  /// Obtiene tags por rango de confianza (para análisis de calidad)
  Future<Map<String, int>> countByConfidenceRange() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('''
      SELECT
        CASE
          WHEN confidence >= 0.9 THEN 'very_high'
          WHEN confidence >= 0.8 THEN 'high'
          WHEN confidence >= 0.6 THEN 'medium'
          ELSE 'low'
        END as range,
        COUNT(*) as count
      FROM image_tags
      GROUP BY range
      ORDER BY range DESC
    ''');

    final map = <String, int>{};
    for (final row in result) {
      map[row['range'] as String] = row['count'] as int;
    }
    return map;
  }
}

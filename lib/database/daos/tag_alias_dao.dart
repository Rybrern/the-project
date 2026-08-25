import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Modelo para un alias de tag
class TagAlias {
  const TagAlias({
    required this.id,
    required this.tagId,
    required this.aliasText,
    required this.normalizedAlias,
    this.source,
    this.confidence = 0.8,
    required this.createdAt,
  });

  final int id;
  final int tagId;
  final String aliasText; // "messi", "Leo Messi", "M10"
  final String normalizedAlias; // "messi", "leo messi", "m10" (para búsqueda)
  final String? source; // "api_metadata", "user_input", "visual_analysis"
  final double confidence;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'tag_id': tagId,
    'alias_text': aliasText,
    'normalized_alias': normalizedAlias,
    'source': source,
    'confidence': confidence,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory TagAlias.fromMap(Map<String, dynamic> map) => TagAlias(
    id: map['id'] as int,
    tagId: map['tag_id'] as int,
    aliasText: map['alias_text'] as String,
    normalizedAlias: map['normalized_alias'] as String,
    source: map['source'] as String?,
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.8,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((map['created_at'] as int?) ?? 0) * 1000,
    ),
  );
}

/// DAO para operaciones con aliases de tags
class TagAliasDAO {
  final AppDatabase _appDatabase;

  TagAliasDAO(this._appDatabase);

  /// Inserta un nuevo alias
  Future<int> insert(TagAlias alias) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'tag_aliases',
      alias.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta múltiples aliases en batch
  Future<void> insertBatch(List<TagAlias> aliases) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final alias in aliases) {
      batch.insert('tag_aliases', alias.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  /// Obtiene un alias por ID
  Future<TagAlias?> getById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query('tag_aliases', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return TagAlias.fromMap(maps.first);
  }

  /// Obtiene todos los aliases para un tag específico
  Future<List<TagAlias>> getByTagId(int tagId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_aliases',
      where: 'tag_id = ?',
      whereArgs: [tagId],
      orderBy: 'confidence DESC',
    );
    return maps.map((map) => TagAlias.fromMap(map)).toList();
  }

  /// Resuelve un alias a un tag ID (búsqueda normalizada)
  /// Retorna el tag ID si encuentra coincidencia, null si no
  Future<int?> resolveAlias(String normalizedAlias) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_aliases',
      columns: ['tag_id'],
      where: 'normalized_alias = ?',
      whereArgs: [normalizedAlias],
      orderBy: 'confidence DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['tag_id'] as int?;
  }

  /// Busca aliases por texto parcial
  Future<List<TagAlias>> searchByText(String query, {int limit = 20}) async {
    final db = await _appDatabase.database;
    final escapedQuery = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'tag_aliases',
      where: 'LOWER(alias_text) LIKE ?',
      whereArgs: [escapedQuery],
      limit: limit,
      orderBy: 'confidence DESC, alias_text ASC',
    );
    return maps.map((map) => TagAlias.fromMap(map)).toList();
  }

  /// Obtiene aliases por texto normalizado (para búsqueda exacta normalizada)
  Future<List<TagAlias>> getByNormalizedAlias(String normalizedAlias) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_aliases',
      where: 'normalized_alias = ?',
      whereArgs: [normalizedAlias],
      orderBy: 'confidence DESC',
    );
    return maps.map((map) => TagAlias.fromMap(map)).toList();
  }

  /// Obtiene aliases por fuente (para auditoría)
  Future<List<TagAlias>> getBySource(String source, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_aliases',
      where: 'source = ?',
      whereArgs: [source],
      limit: limit,
      orderBy: 'confidence DESC',
    );
    return maps.map((map) => TagAlias.fromMap(map)).toList();
  }

  /// Actualiza un alias
  Future<int> update(TagAlias alias) async {
    final db = await _appDatabase.database;
    return await db.update(
      'tag_aliases',
      alias.toMap(),
      where: 'id = ?',
      whereArgs: [alias.id],
    );
  }

  /// Elimina un alias
  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return await db.delete('tag_aliases', where: 'id = ?', whereArgs: [id]);
  }

  /// Elimina todos los aliases de un tag
  Future<int> deleteByTagId(int tagId) async {
    final db = await _appDatabase.database;
    return await db.delete('tag_aliases', where: 'tag_id = ?', whereArgs: [tagId]);
  }

  /// Cuenta total de aliases
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tag_aliases');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Cuenta aliases por confianza (para análisis de calidad)
  Future<Map<String, int>> countByConfidenceRange() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('''
      SELECT
        CASE
          WHEN confidence >= 0.9 THEN 'high'
          WHEN confidence >= 0.7 THEN 'medium'
          ELSE 'low'
        END as range,
        COUNT(*) as count
      FROM tag_aliases
      GROUP BY range
    ''');

    final map = <String, int>{};
    for (final row in result) {
      map[row['range'] as String] = row['count'] as int;
    }
    return map;
  }
}

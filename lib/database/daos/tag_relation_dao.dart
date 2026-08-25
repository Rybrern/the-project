import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Modelo para una relación entre tags
class TagRelation {
  const TagRelation({
    required this.id,
    required this.sourceTagId,
    required this.targetTagId,
    required this.relationType,
    required this.createdAt,
  });

  final int id;
  final int sourceTagId; // Lionel Messi (10001)
  final int targetTagId; // Inter Miami (20045)
  final String relationType; // "player_of_team", "represents_country", "plays_sport"
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'source_tag_id': sourceTagId,
    'target_tag_id': targetTagId,
    'relation_type': relationType,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory TagRelation.fromMap(Map<String, dynamic> map) => TagRelation(
    id: map['id'] as int,
    sourceTagId: map['source_tag_id'] as int,
    targetTagId: map['target_tag_id'] as int,
    relationType: map['relation_type'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((map['created_at'] as int?) ?? 0) * 1000,
    ),
  );
}

/// DAO para operaciones con relaciones entre tags
class TagRelationDAO {
  final AppDatabase _appDatabase;

  TagRelationDAO(this._appDatabase);

  /// Inserta una nueva relación
  Future<int> insert(TagRelation relation) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'tag_relations',
      relation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta múltiples relaciones en batch
  Future<void> insertBatch(List<TagRelation> relations) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final relation in relations) {
      batch.insert('tag_relations', relation.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  /// Obtiene una relación por ID
  Future<TagRelation?> getById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query('tag_relations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return TagRelation.fromMap(maps.first);
  }

  /// Obtiene tags relacionados a partir de un tag fuente
  /// Ejemplo: desde Lionel Messi → obtener Inter Miami, Argentina, Football, etc.
  Future<List<TagRelation>> getBySourceTagId(int sourceTagId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_relations',
      where: 'source_tag_id = ?',
      whereArgs: [sourceTagId],
      orderBy: 'relation_type ASC',
    );
    return maps.map((map) => TagRelation.fromMap(map)).toList();
  }

  /// Obtiene tags que apuntan a un tag destino (relaciones inversas)
  /// Ejemplo: buscar todos los jugadores que juegan para Inter Miami
  Future<List<TagRelation>> getByTargetTagId(int targetTagId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_relations',
      where: 'target_tag_id = ?',
      whereArgs: [targetTagId],
      orderBy: 'relation_type ASC',
    );
    return maps.map((map) => TagRelation.fromMap(map)).toList();
  }

  /// Obtiene todas las relaciones de un tipo específico
  Future<List<TagRelation>> getByRelationType(String relationType) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_relations',
      where: 'relation_type = ?',
      whereArgs: [relationType],
    );
    return maps.map((map) => TagRelation.fromMap(map)).toList();
  }

  /// Obtiene relaciones entre dos tags específicos
  Future<List<TagRelation>> getRelationsBetween(int sourceTagId, int targetTagId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tag_relations',
      where: 'source_tag_id = ? AND target_tag_id = ?',
      whereArgs: [sourceTagId, targetTagId],
    );
    return maps.map((map) => TagRelation.fromMap(map)).toList();
  }

  /// Expande un tag a todos sus relacionados (hasta cierta profundidad)
  /// Ejemplo: expandir Lionel Messi → [Inter Miami, Argentina, Football, World Cup 2022]
  Future<List<int>> expandTag(int tagId, {int maxDepth = 2}) async {
    final db = await _appDatabase.database;
    final expanded = <int>{tagId};
    final toProcess = <int>[tagId];
    var depth = 0;

    while (toProcess.isNotEmpty && depth < maxDepth) {
      final current = toProcess.removeAt(0);
      final maps = await db.query(
        'tag_relations',
        columns: ['target_tag_id'],
        where: 'source_tag_id = ?',
        whereArgs: [current],
      );

      for (final map in maps) {
        final targetId = map['target_tag_id'] as int;
        if (!expanded.contains(targetId)) {
          expanded.add(targetId);
          toProcess.add(targetId);
        }
      }
      depth++;
    }

    return expanded.toList();
  }

  /// Obtiene tipos de relaciones disponibles (para auditoría y validación)
  Future<List<String>> getRelationTypes() async {
    final db = await _appDatabase.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT relation_type FROM tag_relations ORDER BY relation_type ASC'
    );
    return maps.map((map) => map['relation_type'] as String).toList();
  }

  /// Actualiza una relación
  Future<int> update(TagRelation relation) async {
    final db = await _appDatabase.database;
    return await db.update(
      'tag_relations',
      relation.toMap(),
      where: 'id = ?',
      whereArgs: [relation.id],
    );
  }

  /// Elimina una relación
  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return await db.delete('tag_relations', where: 'id = ?', whereArgs: [id]);
  }

  /// Elimina todas las relaciones de un tag (limpieza)
  Future<int> deleteBySourceTagId(int sourceTagId) async {
    final db = await _appDatabase.database;
    return await db.delete('tag_relations', where: 'source_tag_id = ?', whereArgs: [sourceTagId]);
  }

  /// Cuenta total de relaciones
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tag_relations');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Obtiene estadísticas de relaciones
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_relations,
        COUNT(DISTINCT relation_type) as unique_relation_types,
        COUNT(DISTINCT source_tag_id) as tags_with_relations,
        COUNT(DISTINCT target_tag_id) as tags_related_to
      FROM tag_relations
    ''');

    final row = result.first;
    return {
      'total_relations': row['total_relations'],
      'unique_relation_types': row['unique_relation_types'],
      'tags_with_relations': row['tags_with_relations'],
      'tags_related_to': row['tags_related_to'],
    };
  }
}

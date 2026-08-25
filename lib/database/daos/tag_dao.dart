import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Modelo de datos para un tag
class Tag {
  const Tag({
    required this.id,
    required this.canonicalName,
    required this.displayName,
    required this.tagType,
    this.description,
    this.parentTagId,
    this.confidence = 0.95,
    required this.createdAt,
  });

  final int id;
  final String canonicalName; // 'lionel-messi'
  final String displayName; // 'Lionel Messi'
  final String tagType; // 'PERSON', 'TEAM', etc.
  final String? description;
  final int? parentTagId;
  final double confidence;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'canonical_name': canonicalName,
    'display_name': displayName,
    'tag_type': tagType,
    'description': description,
    'parent_tag_id': parentTagId,
    'confidence': confidence,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
    id: map['id'] as int,
    canonicalName: map['canonical_name'] as String,
    displayName: map['display_name'] as String,
    tagType: map['tag_type'] as String,
    description: map['description'] as String?,
    parentTagId: map['parent_tag_id'] as int?,
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((map['created_at'] as int?) ?? 0) * 1000,
    ),
  );
}

/// DAO para operaciones CRUD de tags
class TagDAO {
  final AppDatabase _appDatabase;

  TagDAO(this._appDatabase);

  /// Inserta un nuevo tag
  Future<int> insert(Tag tag) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta múltiples tags en batch
  Future<void> insertBatch(List<Tag> tags) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final tag in tags) {
      batch.insert('tags', tag.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  /// Obtiene un tag por ID
  Future<Tag?> getById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query('tags', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Obtiene un tag por nombre canónico
  Future<Tag?> getByCanonicalName(String canonicalName) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tags',
      where: 'canonical_name = ?',
      whereArgs: [canonicalName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Obtiene todos los tags de un tipo específico
  Future<List<Tag>> getByType(String tagType, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tags',
      where: 'tag_type = ?',
      whereArgs: [tagType],
      limit: limit,
      orderBy: 'display_name ASC',
    );
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Obtiene tags secundarios de un tag padre
  Future<List<Tag>> getChildren(int parentTagId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tags',
      where: 'parent_tag_id = ?',
      whereArgs: [parentTagId],
      orderBy: 'display_name ASC',
    );
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Busca tags por nombre (búsqueda parcial en display_name)
  Future<List<Tag>> searchByDisplayName(String query, {int limit = 20}) async {
    final db = await _appDatabase.database;
    final escapedQuery = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'tags',
      where: 'LOWER(display_name) LIKE ?',
      whereArgs: [escapedQuery],
      limit: limit,
      orderBy: 'display_name ASC',
    );
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Obtiene todos los tags (paginado)
  Future<List<Tag>> getAll({int limit = 1000, int offset = 0}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tags',
      limit: limit,
      offset: offset,
      orderBy: 'display_name ASC',
    );
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Actualiza un tag existente
  Future<int> update(Tag tag) async {
    final db = await _appDatabase.database;
    return await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  /// Elimina un tag
  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  /// Cuenta total de tags
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tags');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Cuenta tags por tipo
  Future<int> countByType(String tagType) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tags WHERE tag_type = ?',
      [tagType],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Obtiene tags populares (más usados en imágenes)
  Future<List<Map<String, dynamic>>> getPopularTags({int limit = 20}) async {
    final db = await _appDatabase.database;
    return await db.rawQuery('''
      SELECT t.*, COUNT(it.id) as usage_count
      FROM tags t
      LEFT JOIN image_tags it ON t.id = it.tag_id
      GROUP BY t.id
      ORDER BY usage_count DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Inserta o actualiza un tag canónico (upsert)
  /// Si el tag existe, lo actualiza; si no, lo crea
  Future<int> upsertCanonical({
    required String canonicalName,
    required String displayName,
    required String tagType,
    String? description,
    int? parentTagId,
    double confidence = 0.95,
  }) async {
    // Intenta obtener el tag existente
    final existing = await getByCanonicalName(canonicalName);

    if (existing != null) {
      // Actualizar si la confianza es mayor
      if (confidence > existing.confidence) {
        await update(existing.copyWith(confidence: confidence));
      }
      return existing.id;
    } else {
      // Crear nuevo tag
      final tag = Tag(
        id: 0,
        canonicalName: canonicalName,
        displayName: displayName,
        tagType: tagType,
        description: description,
        parentTagId: parentTagId,
        confidence: confidence,
        createdAt: DateTime.now(),
      );
      return await insert(tag);
    }
  }

  /// Obtiene todos los tags paginados
  Future<List<Tag>> getAllPaginated({int limit = 1000, int offset = 0}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'tags',
      limit: limit,
      offset: offset,
      orderBy: 'display_name ASC',
    );
    return maps.map((map) => Tag.fromMap(map)).toList();
  }
}

/// Extension para Tag copyWith
extension TagCopyWithExt on Tag {
  Tag copyWith({
    int? id,
    String? canonicalName,
    String? displayName,
    String? tagType,
    String? description,
    int? parentTagId,
    double? confidence,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      canonicalName: canonicalName ?? this.canonicalName,
      displayName: displayName ?? this.displayName,
      tagType: tagType ?? this.tagType,
      description: description ?? this.description,
      parentTagId: parentTagId ?? this.parentTagId,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Search index entry
class SearchIndexEntry {
  const SearchIndexEntry({
    required this.id,
    required this.wallpaperId,
    required this.queryText,
    this.entityType,
    required this.relevance,
    required this.createdAt,
  });

  final int id;
  final String wallpaperId;
  final String queryText; // normalized
  final String? entityType; // 'player', 'team', 'tag', 'general'
  final double relevance;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'wallpaper_id': wallpaperId,
    'query_text': queryText,
    'entity_type': entityType,
    'relevance': relevance,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory SearchIndexEntry.fromMap(Map<String, dynamic> map) => SearchIndexEntry(
    id: map['id'] as int,
    wallpaperId: map['wallpaper_id'] as String,
    queryText: map['query_text'] as String,
    entityType: map['entity_type'] as String?,
    relevance: (map['relevance'] as num).toDouble(),
    createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
  );
}

/// DAO for search index
class SearchIndexDAO {
  final AppDatabase _appDatabase;

  SearchIndexDAO(this._appDatabase);

  /// Insert a search index entry
  Future<int> insert(SearchIndexEntry entry) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'search_index',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple entries in batch
  Future<void> insertBatch(List<SearchIndexEntry> entries) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'search_index',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// Search by query text (returns wallpaper IDs)
  Future<List<String>> search(String queryText, {String? entityType}) async {
    final db = await _appDatabase.database;
    final where = entityType != null
        ? 'query_text = ? AND entity_type = ?'
        : 'query_text = ?';
    final whereArgs = entityType != null
        ? [queryText, entityType]
        : [queryText];

    final maps = await db.query(
      'search_index',
      columns: ['wallpaper_id'],
      where: where,
      whereArgs: whereArgs,
      distinct: true,
      orderBy: 'relevance DESC',
    );

    return maps.map((m) => m['wallpaper_id'] as String).toList();
  }

  /// Search with fuzzy matching (LIKE %query%)
  Future<List<String>> searchFuzzy(String queryText, {String? entityType}) async {
    final db = await _appDatabase.database;
    final where = entityType != null
        ? 'query_text LIKE ? AND entity_type = ?'
        : 'query_text LIKE ?';
    final whereArgs = entityType != null
        ? ['%$queryText%', entityType]
        : ['%$queryText%'];

    final maps = await db.query(
      'search_index',
      columns: ['wallpaper_id'],
      where: where,
      whereArgs: whereArgs,
      distinct: true,
      orderBy: 'relevance DESC',
    );

    return maps.map((m) => m['wallpaper_id'] as String).toList();
  }

  /// Get autocomplete suggestions
  Future<List<String>> getAutocompleteSuggestions(String prefix, {int limit = 10}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'search_index',
      columns: ['DISTINCT query_text'],
      where: 'query_text LIKE ?',
      whereArgs: ['$prefix%'],
      limit: limit,
      orderBy: 'relevance DESC, query_text',
    );

    return maps.map((m) => m['query_text'] as String).toList();
  }

  /// Delete all search entries for a wallpaper
  Future<void> deleteByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    await db.delete(
      'search_index',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
    );
  }

  /// Rebuild search index from wallpapers (call when needed)
  Future<void> rebuildIndex() async {
    final db = await _appDatabase.database;
    await db.delete('search_index');
    // Rebuild logic will be implemented in SearchService
  }

  /// Get all entries for a wallpaper
  Future<List<SearchIndexEntry>> getByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'search_index',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
    );
    return maps.map((map) => SearchIndexEntry.fromMap(map)).toList();
  }

  /// Count total search entries
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM search_index');
    return (result.first['count'] as int?) ?? 0;
  }
}

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Data structure for animated wallpapers with full metadata
class AnimatedWallpaperData {
  const AnimatedWallpaperData({
    required this.id,
    required this.externalId,
    required this.previewImageUrl,
    required this.videoUrl,
    this.previewVideoUrl,
    this.width,
    this.height,
    this.source,
    this.sourceId,
    this.nsfwScore,
    this.qualityScore,
    this.primaryCategory,
    this.subcategory,
    this.tags,
    this.searchTokens,
    this.entityMetadata,
    this.processedAt,
    this.processingStatus,
    required this.createdAt,
  });

  final int id;
  final String externalId;
  final String previewImageUrl;
  final String videoUrl;
  final String? previewVideoUrl;
  final int? width;
  final int? height;
  final String? source;
  final String? sourceId;
  final double? nsfwScore;
  final double? qualityScore;
  final String? primaryCategory;
  final String? subcategory;
  final String? tags; // JSON
  final String? searchTokens; // JSON
  final String? entityMetadata; // JSON
  final DateTime? processedAt;
  final String? processingStatus;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'external_id': externalId,
    'preview_image_url': previewImageUrl,
    'video_url': videoUrl,
    'preview_video_url': previewVideoUrl,
    'width': width,
    'height': height,
    'source': source,
    'source_id': sourceId,
    'nfsw_score': nsfwScore,
    'quality_score': qualityScore,
    'primary_category': primaryCategory,
    'subcategory': subcategory,
    'tags': tags,
    'search_tokens': searchTokens,
    'entity_metadata': entityMetadata,
    'processed_at': processedAt != null ? (processedAt!.millisecondsSinceEpoch ~/ 1000) : null,
    'processing_status': processingStatus,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory AnimatedWallpaperData.fromMap(Map<String, dynamic> map) =>
      AnimatedWallpaperData(
        id: map['id'] as int,
        externalId: map['external_id'] as String,
        previewImageUrl: map['preview_image_url'] as String,
        videoUrl: map['video_url'] as String,
        previewVideoUrl: map['preview_video_url'] as String?,
        width: map['width'] as int?,
        height: map['height'] as int?,
        source: map['source'] as String?,
        sourceId: map['source_id'] as String?,
        nsfwScore: (map['nfsw_score'] as num?)?.toDouble(),
        qualityScore: (map['quality_score'] as num?)?.toDouble(),
        primaryCategory: map['primary_category'] as String?,
        subcategory: map['subcategory'] as String?,
        tags: map['tags'] as String?,
        searchTokens: map['search_tokens'] as String?,
        entityMetadata: map['entity_metadata'] as String?,
        processedAt: map['processed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch((map['processed_at'] as int) * 1000)
            : null,
        processingStatus: map['processing_status'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
      );
}

/// DAO for animated wallpapers
class AnimatedWallpaperDAO {
  final AppDatabase _appDatabase;

  AnimatedWallpaperDAO(this._appDatabase);

  /// Insert an animated wallpaper
  Future<int> insert(AnimatedWallpaperData wallpaper) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'animated_wallpapers',
      wallpaper.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple animated wallpapers
  Future<void> insertBatch(List<AnimatedWallpaperData> wallpapers) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final wallpaper in wallpapers) {
      batch.insert(
        'animated_wallpapers',
        wallpaper.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// Get by ID
  Future<AnimatedWallpaperData?> getById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'animated_wallpapers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AnimatedWallpaperData.fromMap(maps.first);
  }

  /// Get by external ID
  Future<AnimatedWallpaperData?> getByExternalId(String externalId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'animated_wallpapers',
      where: 'external_id = ?',
      whereArgs: [externalId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AnimatedWallpaperData.fromMap(maps.first);
  }

  /// Get by category (with pagination)
  Future<List<AnimatedWallpaperData>> getByCategory(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'animated_wallpapers',
      where: 'primary_category = ?',
      whereArgs: [category],
      limit: limit,
      offset: offset,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AnimatedWallpaperData.fromMap(map)).toList();
  }

  /// Search by query text
  Future<List<AnimatedWallpaperData>> search(String query) async {
    final db = await _appDatabase.database;
    final escapedQuery = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'animated_wallpapers',
      where: 'search_tokens LIKE ? OR tags LIKE ? OR primary_category LIKE ?',
      whereArgs: [escapedQuery, escapedQuery, escapedQuery],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AnimatedWallpaperData.fromMap(map)).toList();
  }

  /// Get recent animated wallpapers
  Future<List<AnimatedWallpaperData>> getRecent({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'animated_wallpapers',
      limit: limit,
      offset: offset,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AnimatedWallpaperData.fromMap(map)).toList();
  }

  /// Get by processing status
  Future<List<AnimatedWallpaperData>> getByProcessingStatus(
    String status, {
    int limit = 20,
  }) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'animated_wallpapers',
      where: 'processing_status = ?',
      whereArgs: [status],
      limit: limit,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AnimatedWallpaperData.fromMap(map)).toList();
  }

  /// Update processing status
  Future<int> updateProcessingStatus(int id, String status) async {
    final db = await _appDatabase.database;
    return await db.update(
      'animated_wallpapers',
      {'processing_status': status, 'processed_at': DateTime.now().millisecondsSinceEpoch ~/ 1000},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete by ID
  Future<int> delete(int id) async {
    final db = await _appDatabase.database;
    return await db.delete(
      'animated_wallpapers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count total
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM animated_wallpapers');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Count by category
  Future<int> countByCategory(String category) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM animated_wallpapers WHERE primary_category = ?',
      [category],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Check if external ID exists
  Future<bool> existsByExternalId(String externalId) async {
    final db = await _appDatabase.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM animated_wallpapers WHERE external_id = ?',
        [externalId],
      ),
    );
    return (count ?? 0) > 0;
  }
}

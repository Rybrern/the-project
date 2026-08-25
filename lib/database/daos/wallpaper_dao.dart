import 'package:sqflite/sqflite.dart';
import '../../models/wallpaper.dart';
import '../app_database.dart';
import 'wallpaper_resolution_dao.dart';

class WallpaperDAO {
  final AppDatabase _appDatabase;

  WallpaperDAO(this._appDatabase);

  Future<void> insert(Wallpaper wallpaper) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'wallpapers',
      {
        'id': wallpaper.id,
        'thumbnail_url': wallpaper.thumbnailUrl,
        'full_url': wallpaper.fullUrl,
        'author': wallpaper.author,
        'category': wallpaper.category,
        'aspect_ratio': wallpaper.aspectRatio,
        'force_portrait_crop': wallpaper.forcePortraitCrop ? 1 : 0,
        'source': wallpaper.source,
        'source_id': wallpaper.sourceId,
        'original_url': wallpaper.originalUrl,
        'file_hash': wallpaper.fileHash,
        'perceptual_hash': wallpaper.perceptualHash,
        'nsfw_score': wallpaper.nsfwScore,
        'quality_score': wallpaper.qualityScore,
        'primary_category': wallpaper.primaryCategory,
        'subcategory': wallpaper.subcategory,
        'tags': wallpaper.tags?.join(','),
        'processed_at': wallpaper.processedAt?.millisecondsSinceEpoch,
        'processing_status': wallpaper.processingStatus,
        'rejection_reason': wallpaper.rejectionReason,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Wallpaper?> getById(String id) async {
    final db = await _appDatabase.database;
    final maps = await db.query('wallpapers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _mapToWallpaper(maps.first);
  }

  Future<List<Wallpaper>> getByCategory(String categoryId, {int limit = 24}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpapers',
      where: 'primary_category = ? OR category = ?',
      whereArgs: [categoryId, categoryId],
      limit: limit,
    );
    return maps.map(_mapToWallpaper).toList();
  }

  Future<List<Wallpaper>> getBySubcategory(String subcategoryId, {int limit = 24}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpapers',
      where: 'subcategory = ?',
      whereArgs: [subcategoryId],
      limit: limit,
    );
    return maps.map(_mapToWallpaper).toList();
  }

  Future<List<Wallpaper>> getBySource(String source, {int limit = 100}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpapers',
      where: 'source = ?',
      whereArgs: [source],
      limit: limit,
    );
    return maps.map(_mapToWallpaper).toList();
  }

  Future<List<Wallpaper>> getAllAccepted({int limit = 1000}) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpapers',
      where: 'processing_status = ?',
      whereArgs: ['accepted'],
      limit: limit,
    );
    return maps.map(_mapToWallpaper).toList();
  }

  Future<int> getCountByCategory(String categoryId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wallpapers WHERE primary_category = ? OR category = ?',
      [categoryId, categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalCount() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM wallpapers');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Wallpaper?> getByFileHash(String hash) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpapers',
      where: 'file_hash = ?',
      whereArgs: [hash],
    );
    if (maps.isEmpty) return null;
    return _mapToWallpaper(maps.first);
  }

  Future<void> update(Wallpaper wallpaper) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'wallpapers',
      {
        'thumbnail_url': wallpaper.thumbnailUrl,
        'full_url': wallpaper.fullUrl,
        'author': wallpaper.author,
        'category': wallpaper.category,
        'aspect_ratio': wallpaper.aspectRatio,
        'force_portrait_crop': wallpaper.forcePortraitCrop ? 1 : 0,
        'source': wallpaper.source,
        'source_id': wallpaper.sourceId,
        'original_url': wallpaper.originalUrl,
        'file_hash': wallpaper.fileHash,
        'perceptual_hash': wallpaper.perceptualHash,
        'nsfw_score': wallpaper.nsfwScore,
        'quality_score': wallpaper.qualityScore,
        'primary_category': wallpaper.primaryCategory,
        'subcategory': wallpaper.subcategory,
        'tags': wallpaper.tags?.join(','),
        'processed_at': wallpaper.processedAt?.millisecondsSinceEpoch,
        'processing_status': wallpaper.processingStatus,
        'rejection_reason': wallpaper.rejectionReason,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [wallpaper.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _appDatabase.database;
    await db.delete('wallpapers', where: 'id = ?', whereArgs: [id]);
  }

  Wallpaper _mapToWallpaper(Map<String, dynamic> map) {
    return Wallpaper(
      id: map['id'] as String,
      thumbnailUrl: map['thumbnail_url'] as String,
      fullUrl: map['full_url'] as String,
      author: map['author'] as String,
      category: map['category'] as String,
      aspectRatio: (map['aspect_ratio'] as num).toDouble(),
      forcePortraitCrop: (map['force_portrait_crop'] as int?) == 1,
      source: map['source'] as String?,
      sourceId: map['source_id'] as String?,
      originalUrl: map['original_url'] as String?,
      fileHash: map['file_hash'] as String?,
      perceptualHash: map['perceptual_hash'] as String?,
      nsfwScore: (map['nsfw_score'] as num?)?.toDouble(),
      qualityScore: (map['quality_score'] as num?)?.toDouble(),
      primaryCategory: map['primary_category'] as String?,
      subcategory: map['subcategory'] as String?,
      tags: (map['tags'] as String?)?.split(','),
      processedAt: map['processed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['processed_at'] as int)
          : null,
      processingStatus: map['processing_status'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
      // previewUrl se cargaría desde resolutions[type='preview']
      // resolutions se cargarían por separado via WallpaperResolutionDAO
    );
  }

  /// Carga resolutions de un wallpaper
  Future<List<WallpaperResolution>> getResolutions(String wallpaperId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpaper_resolutions',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
      orderBy: 'resolution_type DESC',
    );
    return maps.map((map) => WallpaperResolution.fromMap(map)).toList();
  }

  /// Carga un wallpaper con todas sus resoluciones
  Future<Wallpaper?> getByIdWithResolutions(String id) async {
    final wallpaper = await getById(id);
    if (wallpaper == null) return null;

    final resolutions = await getResolutions(id);
    return wallpaper.copyWith(resolutions: resolutions);
  }
}

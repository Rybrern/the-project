import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// Data structure for wallpaper resolutions
class WallpaperResolution {
  const WallpaperResolution({
    required this.id,
    required this.wallpaperId,
    required this.resolutionType,
    required this.url,
    this.width,
    this.height,
    this.fileSizeBytes,
    required this.createdAt,
  });

  final int id;
  final String wallpaperId;
  final String resolutionType; // 'thumbnail', 'preview', 'original'
  final String url;
  final int? width;
  final int? height;
  final int? fileSizeBytes;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'wallpaper_id': wallpaperId,
    'resolution_type': resolutionType,
    'url': url,
    'width': width,
    'height': height,
    'file_size_bytes': fileSizeBytes,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  factory WallpaperResolution.fromMap(Map<String, dynamic> map) => WallpaperResolution(
    id: map['id'] as int,
    wallpaperId: map['wallpaper_id'] as String,
    resolutionType: map['resolution_type'] as String,
    url: map['url'] as String,
    width: map['width'] as int?,
    height: map['height'] as int?,
    fileSizeBytes: map['file_size_bytes'] as int?,
    createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
  );
}

/// DAO for wallpaper resolutions
class WallpaperResolutionDAO {
  final AppDatabase _appDatabase;

  WallpaperResolutionDAO(this._appDatabase);

  /// Insert a new resolution
  Future<int> insert(WallpaperResolution resolution) async {
    final db = await _appDatabase.database;
    return await db.insert(
      'wallpaper_resolutions',
      resolution.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple resolutions
  Future<void> insertBatch(List<WallpaperResolution> resolutions) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    for (final resolution in resolutions) {
      batch.insert(
        'wallpaper_resolutions',
        resolution.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// Get all resolutions for a wallpaper
  Future<List<WallpaperResolution>> getByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpaper_resolutions',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
      orderBy: 'resolution_type DESC',
    );
    return maps.map((map) => WallpaperResolution.fromMap(map)).toList();
  }

  /// Get specific resolution by type
  Future<WallpaperResolution?> getByType(String wallpaperId, String type) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpaper_resolutions',
      where: 'wallpaper_id = ? AND resolution_type = ?',
      whereArgs: [wallpaperId, type],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WallpaperResolution.fromMap(maps.first);
  }

  /// Check if URL exists
  Future<bool> existsByUrl(String url) async {
    final db = await _appDatabase.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM wallpaper_resolutions WHERE url = ?',
        [url],
      ),
    );
    return (count ?? 0) > 0;
  }

  /// Delete all resolutions for a wallpaper
  Future<void> deleteByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    await db.delete(
      'wallpaper_resolutions',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
    );
  }

  /// Get all resolutions of a specific type
  Future<List<WallpaperResolution>> getAllByType(String type) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'wallpaper_resolutions',
      where: 'resolution_type = ?',
      whereArgs: [type],
    );
    return maps.map((map) => WallpaperResolution.fromMap(map)).toList();
  }

  /// Count total resolutions
  Future<int> count() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM wallpaper_resolutions');
    return (result.first['count'] as int?) ?? 0;
  }
}

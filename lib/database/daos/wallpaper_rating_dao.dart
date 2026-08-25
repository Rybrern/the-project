import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// DAO para ratings y feedback de wallpapers.
/// Permite a los usuarios calificar y reportar wallpapers.
class WallpaperRatingDAO {
  final AppDatabase _appDatabase;

  WallpaperRatingDAO(this._appDatabase);

  /// Registra una calificación de usuario
  Future<void> rateWallpaper(
    String wallpaperId,
    int rating, {
    String? comment,
    String? userId,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'wallpaper_ratings',
      {
        'wallpaper_id': wallpaperId,
        'user_id': userId,
        'rating': rating, // 1-5 stars
        'comment': comment,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reporta un problema con un wallpaper
  Future<void> reportWallpaper(
    String wallpaperId, {
    required String reason, // 'nsfw', 'quality', 'duplicate', 'offensive'
    String? description,
    String? userId,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'wallpaper_reports',
      {
        'wallpaper_id': wallpaperId,
        'reason': reason,
        'description': description,
        'user_id': userId,
        'created_at': now,
        'status': 'open',
      },
    );
  }

  /// Obtiene rating promedio de un wallpaper
  Future<double> getAverageRating(String wallpaperId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT AVG(rating) as avg FROM wallpaper_ratings WHERE wallpaper_id = ?',
      [wallpaperId],
    );

    if (result.isEmpty) return 0.0;
    final avg = result.first['avg'];
    return avg != null ? (avg as num).toDouble() : 0.0;
  }

  /// Obtiene estadísticas de ratings
  Future<Map<String, dynamic>> getRatingStats(String wallpaperId) async {
    final db = await _appDatabase.database;

    final results = await db.rawQuery(
      '''SELECT rating, COUNT(*) as count
         FROM wallpaper_ratings
         WHERE wallpaper_id = ?
         GROUP BY rating
         ORDER BY rating DESC''',
      [wallpaperId],
    );

    final stats = <int, int>{};
    for (final row in results) {
      stats[row['rating'] as int] = (row['count'] as int?) ?? 0;
    }

    return {
      'total_ratings': results.fold(0, (sum, row) => sum + ((row['count'] as int?) ?? 0)),
      'average': await getAverageRating(wallpaperId),
      'distribution': stats,
    };
  }

  /// Obtiene reportes pendientes
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final db = await _appDatabase.database;
    return db.query(
      'wallpaper_reports',
      where: 'status = ?',
      whereArgs: ['open'],
      orderBy: 'created_at DESC',
    );
  }

  /// Cierra un reporte
  Future<void> closeReport(
    String reportId, {
    required String resolution,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      'wallpaper_reports',
      {
        'status': 'closed',
        'resolution': resolution,
        'closed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// Obtiene wallpapers más calificados
  Future<List<Map<String, dynamic>>> getTopRatedWallpapers({int limit = 50}) async {
    final db = await _appDatabase.database;
    return db.rawQuery(
      '''SELECT w.id, w.full_url, AVG(r.rating) as avg_rating, COUNT(r.id) as rating_count
         FROM wallpapers w
         LEFT JOIN wallpaper_ratings r ON w.id = r.wallpaper_id
         GROUP BY w.id
         ORDER BY avg_rating DESC, rating_count DESC
         LIMIT ?''',
      [limit],
    );
  }

  /// Obtiene comentarios sobre un wallpaper
  Future<List<Map<String, dynamic>>> getComments(String wallpaperId) async {
    final db = await _appDatabase.database;
    return db.query(
      'wallpaper_ratings',
      where: 'wallpaper_id = ? AND comment IS NOT NULL',
      whereArgs: [wallpaperId],
      orderBy: 'created_at DESC',
    );
  }
}

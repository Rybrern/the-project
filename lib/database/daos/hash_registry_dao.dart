import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

/// DAO para el registro de hashes. Permite detectar duplicados
/// basándose en SHA256 y pHash.
class HashRegistryDAO {
  final AppDatabase _appDatabase;

  HashRegistryDAO(this._appDatabase);

  /// Registra un hash en la BD
  Future<void> register({
    required String hash,
    required String wallpaperId,
    required String source,
    String? perceptualHash,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'hash_registry',
      {
        'hash': hash,
        'perceptual_hash': perceptualHash,
        'wallpaper_id': wallpaperId,
        'source': source,
        'registered_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Busca si un hash exacto ya existe
  Future<bool> existsHash(String hash) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'hash_registry',
      where: 'hash = ?',
      whereArgs: [hash],
    );
    return maps.isNotEmpty;
  }

  /// Obtiene el wallpaper_id asociado a un hash
  Future<String?> getWallpaperIdByHash(String hash) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'hash_registry',
      where: 'hash = ?',
      whereArgs: [hash],
    );
    if (maps.isEmpty) return null;
    return maps.first['wallpaper_id'] as String;
  }

  /// Busca si un pHash similar ya existe (umbral de similitud)
  /// Retorna el wallpaper_id si encuentra una coincidencia, null si no
  Future<String?> findSimilarPerceptualHash(
    String perceptualHash, {
    double similarityThreshold = 0.95,
  }) async {
    // Por ahora, búsqueda exacta de pHash
    // En el futuro se puede implementar comparación fuzzy
    final db = await _appDatabase.database;
    final maps = await db.query(
      'hash_registry',
      where: 'perceptual_hash = ?',
      whereArgs: [perceptualHash],
    );

    if (maps.isEmpty) return null;

    // Retorna el primer match encontrado
    // En el futuro se podría calcular distancia de Hamming si se almacena en formato binario
    return maps.first['wallpaper_id'] as String;
  }

  /// Obtiene todos los hashes de un wallpaper específico
  Future<Map<String, dynamic>> getHashesByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'hash_registry',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
    );

    if (maps.isEmpty) return {};

    return {
      'hash': maps.first['hash'],
      'perceptual_hash': maps.first['perceptual_hash'],
      'wallpaper_id': maps.first['wallpaper_id'],
      'source': maps.first['source'],
    };
  }

  /// Obtiene estadísticas de hashes registrados
  Future<Map<String, int>> getStatistics() async {
    final db = await _appDatabase.database;

    final totalCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM hash_registry',
    );
    final totalHashes = Sqflite.firstIntValue(totalCount) ?? 0;

    final uniqueWallpapers = await db.rawQuery(
      'SELECT COUNT(DISTINCT wallpaper_id) as count FROM hash_registry',
    );
    final uniqueCount = Sqflite.firstIntValue(uniqueWallpapers) ?? 0;

    return {
      'total_hashes': totalHashes,
      'unique_wallpapers': uniqueCount,
    };
  }

  /// Elimina todos los hashes de un wallpaper
  Future<void> deleteByWallpaperId(String wallpaperId) async {
    final db = await _appDatabase.database;
    await db.delete(
      'hash_registry',
      where: 'wallpaper_id = ?',
      whereArgs: [wallpaperId],
    );
  }

  /// Limpia hashes huérfanos (wallpapers que ya no existen)
  Future<int> cleanupOrphanedHashes() async {
    final db = await _appDatabase.database;
    final deletedCount = await db.rawDelete(
      '''DELETE FROM hash_registry
         WHERE wallpaper_id NOT IN (SELECT id FROM wallpapers)''',
    );
    return deletedCount;
  }
}

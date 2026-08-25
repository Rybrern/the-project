import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'wallpaper_app.db');

    return openDatabase(
      path,
      version: 6,
      onOpen: _onOpen,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _executeMigrations(db, 1, version);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _executeMigrations(db, oldVersion + 1, newVersion);
  }

  Future<void> _onOpen(Database db) async {
    // Habilita foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _executeMigrations(Database db, int startVersion, int endVersion) async {
    for (var version = startVersion; version <= endVersion; version++) {
      final sql = await _loadMigration(version);
      // Ejecuta cada statement por separado, filtrando comentarios
      final statements = _parseSqlStatements(sql);
      for (final statement in statements) {
        if (statement.isNotEmpty) {
          await db.execute(statement);
        }
      }
    }
  }

  List<String> _parseSqlStatements(String sql) {
    final statements = <String>[];
    final lines = sql.split('\n');
    final buffer = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      // Ignora líneas vacías y comentarios
      if (trimmed.isEmpty || trimmed.startsWith('--')) {
        continue;
      }
      buffer.writeln(line);
    }

    // Divide por punto y coma y filtra vacíos
    final fullSql = buffer.toString();
    final parts = fullSql.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts;
  }

  Future<String> _loadMigration(int version) async {
    final sql = await rootBundle.loadString(
      'lib/database/migrations/00${version}_*.sql'
          .replaceAll('*', _getMigrationName(version)),
    );
    return sql;
  }

  String _getMigrationName(int version) {
    return switch (version) {
      1 => 'initial',
      2 => 'processing',
      3 => 'ratings_reports',
      4 => 'wallpaper_resolutions',
      5 => 'search_and_animated',
      6 => 'tag_system',
      _ => 'unknown',
    };
  }

  /// Cierra la conexión a la base de datos
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Resetea la base de datos (útil para testing)
  Future<void> reset() async {
    await close();

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'wallpaper_app.db');
    await deleteDatabase(path);

    _database = null;
    await database; // Reinicializa
  }
}

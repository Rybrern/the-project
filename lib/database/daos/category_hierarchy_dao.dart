import 'package:sqflite/sqflite.dart';
import '../../models/category_hierarchy.dart';
import '../app_database.dart';

class CategoryHierarchyDAO {
  final AppDatabase _appDatabase;

  CategoryHierarchyDAO(this._appDatabase);

  Future<void> insert(CategoryHierarchy category, {String? parentId}) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'category_hierarchy',
      {
        'id': category.id,
        'parent_id': parentId,
        'name': category.name,
        'emoji': category.emoji,
        'description': category.description,
        'priority': category.priority,
        'force_portrait_crop': category.forcePortraitCrop ? 1 : 0,
        'discovery_queries': category.discoveryQueries?.join('|'),
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Inserta subcategorías recursivamente
    if (category.subcategories != null) {
      for (final sub in category.subcategories!) {
        await insert(sub, parentId: category.id);
      }
    }
  }

  Future<CategoryHierarchy?> getById(String id) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'category_hierarchy',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;

    final map = maps.first;
    final subcategories = await getSubcategories(id);

    return _mapToCategory(map, subcategories);
  }

  Future<List<CategoryHierarchy>> getSubcategories(String parentId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'category_hierarchy',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'priority ASC, name ASC',
    );

    final categories = <CategoryHierarchy>[];
    for (final map in maps) {
      final subSubs = await getSubcategories(map['id'] as String);
      categories.add(_mapToCategory(map, subSubs));
    }

    return categories;
  }

  Future<List<CategoryHierarchy>> getRootCategories() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      'category_hierarchy',
      where: 'parent_id IS NULL',
      orderBy: 'priority ASC, name ASC',
    );

    final categories = <CategoryHierarchy>[];
    for (final map in maps) {
      final subcats = await getSubcategories(map['id'] as String);
      categories.add(_mapToCategory(map, subcats));
    }

    return categories;
  }

  Future<void> delete(String id) async {
    final db = await _appDatabase.database;
    // Elimina todas las subcategorías recursivamente
    final subcats = await getSubcategories(id);
    for (final sub in subcats) {
      await delete(sub.id);
    }
    // Elimina la categoría
    await db.delete('category_hierarchy', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotalCount() async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM category_hierarchy');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  CategoryHierarchy _mapToCategory(
    Map<String, dynamic> map,
    List<CategoryHierarchy>? subcategories,
  ) {
    return CategoryHierarchy(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      description: map['description'] as String?,
      priority: (map['priority'] as int?) ?? 0,
      forcePortraitCrop: (map['force_portrait_crop'] as int?) == 1,
      discoveryQueries: (map['discovery_queries'] as String?)?.split('|'),
      subcategories: subcategories,
    );
  }
}

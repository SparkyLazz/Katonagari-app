
import '../database/app_database.dart';

class CategoryRepository {
  final AppDatabase _db;
  const CategoryRepository(this._db);

  Stream<List<Category>> watchAll() =>
      _db.select(_db.categories).watch();

  Stream<List<Category>> watchByType(String type) {
    return (_db.select(_db.categories)
          ..where((c) => c.type.equals(type)))
        .watch();
  }

  Future<List<Category>> getByType(String type) {
    return (_db.select(_db.categories)
          ..where((c) => c.type.equals(type)))
        .get();
  }

  Future<int> add(CategoriesCompanion entry) =>
      _db.into(_db.categories).insert(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
}
import 'package:drift/drift.dart';

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

  /// Deletes a category. Its transactions are moved to the default "Other"
  /// category of the same type (so they don't vanish from lists and totals),
  /// and its budgets are removed.
  Future<int> delete(int id) {
    return _db.transaction(() async {
      final cat = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(id)))
          .getSingleOrNull();
      if (cat == null) return 0;

      final fallback = await (_db.select(_db.categories)
            ..where((c) =>
                c.type.equals(cat.type) &
                c.name.equals('Other') &
                c.id.equals(id).not())
            ..orderBy([(c) => OrderingTerm.desc(c.isDefault)])
            ..limit(1))
          .getSingleOrNull();
      if (fallback == null) return 0; // keep data rather than orphan it

      await (_db.update(_db.transactions)
            ..where((t) => t.categoryId.equals(id)))
          .write(TransactionsCompanion(categoryId: Value(fallback.id)));
      await (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(id)))
          .go();
      return (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }
}
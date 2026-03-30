import 'package:drift/drift.dart';
import '../database/app_database.dart';

class BudgetRepository {
  final AppDatabase _db;
  const BudgetRepository(this._db);

  Stream<List<Budget>> watchByMonth(int month, int year) {
    return (_db.select(_db.budgets)
          ..where((b) => b.month.equals(month) & b.year.equals(year)))
        .watch();
  }

  Future<int> add(BudgetsCompanion entry) =>
      _db.into(_db.budgets).insert(entry);

  Future<bool> update(BudgetsCompanion entry) =>
      _db.update(_db.budgets).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();

  
  Future<void> upsert({
  required int categoryId,
  required double amount,
  required int month,
  required int year,
}) async {
  // Check if budget already exists for this category/month/year
  final existing = await (_db.select(_db.budgets)
        ..where((b) =>
            b.categoryId.equals(categoryId) &
            b.month.equals(month) &
            b.year.equals(year)))
      .getSingleOrNull();

  if (existing != null) {
    // Update
    await (_db.update(_db.budgets)
          ..where((b) => b.id.equals(existing.id)))
        .write(BudgetsCompanion(amount: Value(amount)));
  } else {
    // Insert
    await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
      categoryId: categoryId,
      amount: amount,
      month: month,
      year: year,
    ));
  }
}
}
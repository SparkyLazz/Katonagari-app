import 'package:drift/drift.dart';
import '../database/app_database.dart';

class DebtRepository {
  final AppDatabase _db;
  const DebtRepository(this._db);

  /// All debts, newest first.
  Stream<List<Debt>> watchAll() => _db.watchDebts();

  /// Filter by type: 'OWE' or 'OWED'.
  Stream<List<Debt>> watchByType(String type) {
    return (_db.select(_db.debts)
      ..where((d) => d.type.equals(type))
      ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<int> add(DebtsCompanion entry) =>
      _db.into(_db.debts).insert(entry);

  Future<bool> update(DebtsCompanion entry) =>
      _db.update(_db.debts).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.debts)..where((d) => d.id.equals(id))).go();

  /// Toggle isPaid on a debt.
  Future<void> markPaid(Debt debt, {bool paid = true}) async {
    await update(
      debt.toCompanion(false).copyWith(isPaid: Value(paid)),
    );
  }
}
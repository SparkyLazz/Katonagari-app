import 'package:drift/drift.dart';
import '../database/app_database.dart';

class TransactionRepository {
  final AppDatabase _db;
  const TransactionRepository(this._db);

  // ── Get all transactions ──
  Stream<List<Transaction>> watchAll() {
    return (_db.select(_db.transactions)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  // ── Get transactions by month ──
  Stream<List<Transaction>> watchByMonth(int month, int year) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (_db.select(_db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }
  Stream<List<TransactionWithCategory>> watchWithCategoryByMonth(
    int month, int year) {
    return _db.watchTransactionsWithCategory(month: month, year: year);
  }

Stream<List<TransactionWithCategory>> watchAllWithCategory() {
    return _db.watchTransactionsWithCategory();
  }

  // ── Add transaction ──
  Future<int> add(TransactionsCompanion entry) {
    return _db.into(_db.transactions).insert(entry);
  }

  // ── Delete transaction ──
  Future<int> delete(int id) {
  return (_db.delete(_db.transactions)
        ..where((t) => t.id.equals(id)))
      .go();
}

  // ── Update transaction ──
  // Writes only the fields present in [entry]; `replace` would reset absent
  // columns (like createdAt) to their defaults.
  Future<bool> update(TransactionsCompanion entry) async {
    final rows = await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
    return rows > 0;
  }

  // ── Get monthly totals ──
  Future<Map<String, double>> getMonthlyTotals(int month, int year) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);

    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end)))
        .get();

    double income = 0;
    double expense = 0;

    for (final t in rows) {
      if (t.type == 'INCOME') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    return {'income': income, 'expense': expense};
  }
}
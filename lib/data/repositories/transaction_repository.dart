import 'package:drift/drift.dart';
import '../database/app_database.dart';

// ── Monthly repeat helpers (pure, unit-tested) ─────────────────────────────

/// The occurrence after [from] for a series repeating on [day] of each
/// month, keeping the time of day. [day] past the end of a short month
/// falls on its last day (31 → 30 Apr / 28 Feb) without drifting later
/// occurrences, because [day] is the intended day, not the previous date.
DateTime nextMonthlyDate(DateTime from, int day) {
  final first       = DateTime(from.year, from.month + 1);
  final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, day.clamp(1, daysInMonth),
      from.hour, from.minute, from.second);
}

/// How many occurrences after [from] fall on or before [today]'s date,
/// i.e. how many copies saving a repeating transaction will add right away.
int missedOccurrences(DateTime from, int day, DateTime today, {int cap = 120}) {
  final end = DateTime(today.year, today.month, today.day + 1);
  var n = 0;
  var cur = from;
  while (n < cap) {
    cur = nextMonthlyDate(cur, day);
    if (!cur.isBefore(end)) break;
    n++;
  }
  return n;
}

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

  // ── Monthly repeating transactions ──
  /// Creates the occurrences of every repeating transaction that are due up
  /// to and including [now]'s date, adjusting wallet balances, and moves the
  /// isRecurring flag to the newest copy. Safe to call repeatedly (a no-op
  /// when nothing is due). Returns how many transactions were created.
  Future<int> generateRecurring({DateTime? now}) {
    final today = now ?? DateTime.now();
    final end   = DateTime(today.year, today.month, today.day + 1);
    return _db.transaction(() async {
      final series = await (_db.select(_db.transactions)
            ..where((t) => t.isRecurring.equals(true) & t.repeatDay.isNotNull()))
          .get();

      var created = 0;
      for (var cur in series) {
        final day = cur.repeatDay!;
        // Cap so corrupt data (e.g. a date far in the past) can't run away
        for (var i = 0; i < 120; i++) {
          final next = nextMonthlyDate(cur.date, day);
          if (!next.isBefore(end)) break;

          final id = await _db.into(_db.transactions).insert(
                TransactionsCompanion.insert(
                  walletId:    cur.walletId,
                  categoryId:  cur.categoryId,
                  type:        cur.type,
                  amount:      cur.amount,
                  note:        Value(cur.note),
                  date:        next,
                  isOneTime:   Value(cur.isOneTime),
                  isRecurring: const Value(true),
                  repeatDay:   Value(day),
                ),
              );
          await (_db.update(_db.transactions)
                ..where((t) => t.id.equals(cur.id)))
              .write(const TransactionsCompanion(isRecurring: Value(false)));
          final delta = cur.type == 'INCOME' ? cur.amount : -cur.amount;
          await (_db.update(_db.wallets)
                ..where((w) => w.id.equals(cur.walletId)))
              .write(WalletsCompanion.custom(
            balance: _db.wallets.balance + Variable(delta),
          ));

          cur = await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id)))
              .getSingle();
          created++;
        }
      }
      return created;
    });
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
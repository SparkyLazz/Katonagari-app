import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katonagari/core/providers/providers.dart';
import 'package:katonagari/data/database/app_database.dart';
import 'package:katonagari/data/repositories/budget_repository.dart';
import 'package:katonagari/data/repositories/goal_repository.dart';
import 'package:katonagari/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<int> walletId() async =>
      (await db.select(db.wallets).get()).first.id;
  Future<int> categoryId(String type) async =>
      (await (db.select(db.categories)..where((c) => c.type.equals(type)))
              .get())
          .first
          .id;

  Future<void> addTx(String type, double amount, DateTime date) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          walletId:   await walletId(),
          categoryId: await categoryId(type),
          type:       type,
          amount:     amount,
          date:       date,
        ));
  }

  group('monthly totals', () {
    test('a new month starts from zero', () async {
      await addTx('INCOME', 5000000, DateTime(2026, 10, 1));
      await addTx('EXPENSE', 1200000, DateTime(2026, 10, 15));

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      container.listen(monthlyTotalsProvider, (_, __) {});

      // Month switches and DB writes reach the totals asynchronously
      Future<double> balance() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        final t = container.read(monthlyTotalsProvider).requireValue;
        return t['income']! - t['expense']!;
      }

      container.read(selectedMonthProvider.notifier).state =
          DateTime(2026, 10);
      expect(await balance(), 3800000);

      container.read(selectedMonthProvider.notifier).state =
          DateTime(2026, 11);
      expect(await balance(), 0);

      await addTx('EXPENSE', 50000, DateTime(2026, 11, 2));
      expect(await balance(), -50000);

      // Going back still shows October's own balance
      container.read(selectedMonthProvider.notifier).state =
          DateTime(2026, 10);
      expect(await balance(), 3800000);
    });
  });

  group('BudgetRepository.copyMonth', () {
    test('copies budgets and skips categories already budgeted', () async {
      final repo = BudgetRepository(db);
      final cats = await (db.select(db.categories)
            ..where((c) => c.type.equals('EXPENSE')))
          .get();

      await repo.upsert(
          categoryId: cats[0].id, amount: 100, month: 10, year: 2026);
      await repo.upsert(
          categoryId: cats[1].id, amount: 200, month: 10, year: 2026);
      await repo.upsert(
          categoryId: cats[1].id, amount: 999, month: 11, year: 2026);

      final created = await repo.copyMonth(
          from: DateTime(2026, 10), to: DateTime(2026, 11));
      expect(created, 1);

      final nov = await repo.watchByMonth(11, 2026).first;
      final byCat = {for (final b in nov) b.categoryId: b.amount};
      expect(byCat, {cats[0].id: 100.0, cats[1].id: 999.0});

      // Copying again is a no-op
      expect(
          await repo.copyMonth(
              from: DateTime(2026, 10), to: DateTime(2026, 11)),
          0);
    });

    test('January copies from December of the previous year', () async {
      final repo = BudgetRepository(db);
      final cat = await categoryId('EXPENSE');
      await repo.upsert(categoryId: cat, amount: 300, month: 12, year: 2026);

      final jan = DateTime(2027, 1);
      final created = await repo.copyMonth(
          from: DateTime(jan.year, jan.month - 1), to: jan);
      expect(created, 1);
      expect((await repo.watchByMonth(1, 2027).first).single.amount, 300);
    });
  });

  test('editing a transaction keeps its createdAt', () async {
    final created = DateTime(2026, 10, 1, 8, 30);
    final id = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            walletId:   await walletId(),
            categoryId: await categoryId('EXPENSE'),
            type:       'EXPENSE',
            amount:     10000,
            date:       DateTime(2026, 10, 1),
            createdAt:  Value(created),
          ),
        );

    final ok = await TransactionRepository(db).update(TransactionsCompanion(
      id:         Value(id),
      walletId:   Value(await walletId()),
      categoryId: Value(await categoryId('EXPENSE')),
      type:       const Value('EXPENSE'),
      amount:     const Value(25000),
      note:       const Value('edited'),
      date:       Value(DateTime(2026, 10, 2)),
    ));
    expect(ok, isTrue);

    final row = await (db.select(db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.amount, 25000);
    expect(row.note, 'edited');
    expect(row.createdAt, created);
  });

  test('goal top-up uses the stored amount, not a stale snapshot', () async {
    final repo = GoalRepository(db);
    final id = await repo.add(GoalsCompanion.insert(
      name: 'Laptop',
      targetAmount: 1000,
    ));
    final stale = await (db.select(db.goals)..where((g) => g.id.equals(id)))
        .getSingle();

    await repo.topUp(stale, 300);
    await repo.topUp(stale, 300); // same old snapshot
    await repo.topUp(stale, 900); // capped at target

    final saved = (await (db.select(db.goals)..where((g) => g.id.equals(id)))
            .getSingle())
        .savedAmount;
    expect(saved, 1000);
  });
}

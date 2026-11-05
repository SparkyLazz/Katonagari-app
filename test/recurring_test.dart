import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katonagari/data/database/app_database.dart';
import 'package:katonagari/data/repositories/transaction_repository.dart';

void main() {
  String d(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  group('nextMonthlyDate', () {
    test('a 31st series uses month-ends without drifting', () {
      var t = DateTime(2027, 1, 31, 9, 15);
      final dates = <String>[];
      for (var i = 0; i < 4; i++) {
        t = nextMonthlyDate(t, 31);
        dates.add(d(t));
      }
      expect(dates, ['2027-02-28', '2027-03-31', '2027-04-30', '2027-05-31']);
      expect([t.hour, t.minute], [9, 15]); // keeps the time of day
    });

    test('crosses the year boundary', () {
      expect(d(nextMonthlyDate(DateTime(2026, 12, 15), 15)), '2027-01-15');
    });
  });

  group('missedOccurrences', () {
    test('counts due dates up to and including today', () {
      expect(missedOccurrences(DateTime(2026, 8, 5), 5, DateTime(2026, 11, 5)),
          3); // Sep 5, Oct 5, Nov 5
      expect(missedOccurrences(DateTime(2026, 8, 5), 5, DateTime(2026, 11, 4)),
          2);
      expect(missedOccurrences(DateTime(2026, 11, 5), 5, DateTime(2026, 11, 5)),
          0);
    });
  });

  group('generateRecurring', () {
    late AppDatabase db;
    late TransactionRepository repo;
    late int walletId;

    setUp(() async {
      db   = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TransactionRepository(db);
      walletId = (await db.select(db.wallets).get()).first.id;
      await (db.update(db.wallets)..where((w) => w.id.equals(walletId)))
          .write(const WalletsCompanion(balance: Value(1000000)));
    });
    tearDown(() => db.close());

    Future<int> catId(String type) async =>
        (await (db.select(db.categories)..where((c) => c.type.equals(type)))
                .get())
            .first
            .id;

    Future<double> balance() async =>
        (await (db.select(db.wallets)..where((w) => w.id.equals(walletId)))
                .getSingle())
            .balance;

    Future<List<Transaction>> all() => (db.select(db.transactions)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    test('catches up missed months, moves the flag, adjusts the wallet, '
        'and is idempotent', () async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            walletId:    walletId,
            categoryId:  await catId('EXPENSE'),
            type:        'EXPENSE',
            amount:      100000,
            note:        const Value('Rent'),
            date:        DateTime(2026, 8, 31, 10),
            isRecurring: const Value(true),
            repeatDay:   const Value(31),
          ));

      expect(await repo.generateRecurring(now: DateTime(2026, 11, 5)), 2);
      var txs = await all();
      expect(txs.map((t) => d(t.date)),
          ['2026-08-31', '2026-09-30', '2026-10-31']);
      expect(txs.map((t) => t.isRecurring), [false, false, true]);
      expect(txs.every((t) => t.note == 'Rent' && t.repeatDay == 31), isTrue);
      expect(await balance(), 1000000 - 200000);

      // Running again the same day adds nothing
      expect(await repo.generateRecurring(now: DateTime(2026, 11, 5)), 0);
      expect(await balance(), 800000);

      // Due on its day (Nov 30), not before
      expect(await repo.generateRecurring(now: DateTime(2026, 11, 29)), 0);
      expect(await repo.generateRecurring(now: DateTime(2026, 11, 30)), 1);
      txs = await all();
      expect(d(txs.last.date), '2026-11-30');
      expect(txs.where((t) => t.isRecurring).length, 1);
    });

    test('income adds to the wallet', () async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            walletId:    walletId,
            categoryId:  await catId('INCOME'),
            type:        'INCOME',
            amount:      5000000,
            date:        DateTime(2026, 10, 25),
            isRecurring: const Value(true),
            repeatDay:   const Value(25),
          ));
      expect(await repo.generateRecurring(now: DateTime(2026, 11, 25)), 1);
      expect(await balance(), 1000000 + 5000000);
    });

    test('ignores legacy rows flagged recurring without a repeat day',
        () async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            walletId:    walletId,
            categoryId:  await catId('EXPENSE'),
            type:        'EXPENSE',
            amount:      1,
            date:        DateTime(2025, 1, 1),
            isRecurring: const Value(true),
          ));
      expect(await repo.generateRecurring(now: DateTime(2026, 11, 5)), 0);
      expect((await all()).length, 1);
    });
  });

  test('migrates a v3 database to v4 without losing transactions', () async {
    final dir  = await Directory.systemTemp.createTemp('katonagari_mig');
    final file = File('${dir.path}/db.sqlite');
    addTearDown(() => dir.delete(recursive: true));

    // Build a v3 database: current schema minus the v4 column
    var db = AppDatabase.forTesting(NativeDatabase(file));
    final walletId = (await db.select(db.wallets).get()).first.id;
    final catId    = (await db.select(db.categories).get()).first.id;
    await db.customStatement('ALTER TABLE transactions DROP COLUMN repeat_day');
    await db.customStatement(
        "INSERT INTO transactions (wallet_id, category_id, type, amount, date) "
        "VALUES ($walletId, $catId, 'EXPENSE', 42000, "
        "${DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000})");
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    final rows = await db.select(db.transactions).get();
    expect(rows.single.amount, 42000);
    expect(rows.single.repeatDay, isNull);

    await (db.update(db.transactions)..where((t) => t.id.equals(rows.single.id)))
        .write(const TransactionsCompanion(repeatDay: Value(1)));
    expect((await db.select(db.transactions).getSingle()).repeatDay, 1);
    await db.close();
  });
}

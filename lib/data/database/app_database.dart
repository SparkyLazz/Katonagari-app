import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────

class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  TextColumn get icon => text().withDefault(const Constant('💰'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get icon => text()();
  TextColumn get color => text().withDefault(const Constant('#C4A778'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isOneTime => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Goals extends Table {
  IntColumn      get id           => integer().autoIncrement()();
  TextColumn     get name         => text()();
  TextColumn     get icon         => text().withDefault(const Constant('🎯'))();
  RealColumn     get targetAmount => real()();
  RealColumn     get savedAmount  => real().withDefault(const Constant(0))();
  DateTimeColumn get targetDate   => dateTime().nullable()();
  DateTimeColumn get createdAt    => dateTime().withDefault(currentDateAndTime)();
}

// ── NEW in v3 ─────────────────────────────────────────
class Debts extends Table {
  IntColumn      get id         => integer().autoIncrement()();
  /// 'OWE' = you owe someone, 'OWED' = someone owes you
  TextColumn     get type       => text()();
  TextColumn     get personName => text()();
  RealColumn     get amount     => real()();
  DateTimeColumn get dueDate    => dateTime().nullable()();
  TextColumn     get note       => text().nullable()();
  BoolColumn     get isPaid     => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt  => dateTime().withDefault(currentDateAndTime)();
}

// ─── Joined result classes — OUTSIDE AppDatabase ──────

class TransactionWithCategory {
  final Transaction transaction;
  final Category category;
  const TransactionWithCategory(this.transaction, this.category);
}

class BudgetWithSpending {
  final Budget budget;
  final Category category;
  final double spent;
  const BudgetWithSpending({
    required this.budget,
    required this.category,
    required this.spent,
  });

  double get pct      => spent / budget.amount;
  bool   get isOver   => pct >= 1.0;
  bool   get isWarn   => pct >= 0.8 && !isOver;
  double get remaining => budget.amount - spent;
}

// ─── Database ─────────────────────────────────────────

@DriftDatabase(tables: [Wallets, Categories, Transactions, Budgets, Goals, Debts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable($GoalsTable(this));
      }
      if (from < 3) {
        await m.createTable($DebtsTable(this));
      }
    },
  );

  // ── watchTransactionsWithCategory ──────────────────────
  Stream<List<TransactionWithCategory>> watchTransactionsWithCategory({
    int? month,
    int? year,
  }) {
    final txTable  = this.transactions;
    final catTable = this.categories;

    final query = select(txTable).join([
      innerJoin(catTable, catTable.id.equalsExp(txTable.categoryId)),
    ]);

    if (month != null && year != null) {
      final start = DateTime(year, month, 1);
      final end   = DateTime(year, month + 1, 0, 23, 59, 59);
      query.where(txTable.date.isBetweenValues(start, end));
    }

    query.orderBy([
      OrderingTerm.desc(txTable.date),
      OrderingTerm.desc(txTable.createdAt),
    ]);

    return query.watch().map((rows) => rows.map((row) {
      return TransactionWithCategory(
        row.readTable(txTable),
        row.readTable(catTable),
      );
    }).toList());
  }

  // ── watchBudgetsWithSpending ───────────────────────────
  Stream<List<BudgetWithSpending>> watchBudgetsWithSpending({
    required int month,
    required int year,
  }) {
    final start = DateTime(year, month, 1);
    final end   = DateTime(year, month + 1, 0, 23, 59, 59);

    final budgetStream = (select(budgets).join([
      innerJoin(categories, categories.id.equalsExp(budgets.categoryId)),
    ])..where(budgets.month.equals(month) & budgets.year.equals(year)))
        .watch();

    final txStream = (select(transactions)
      ..where((t) =>
      t.type.equals('EXPENSE') &
      t.date.isBetweenValues(start, end)))
        .watch();

    return Rx.combineLatest2(
      budgetStream,
      txStream,
          (List<TypedResult> budgetRows, List<Transaction> txRows) {
        final spendMap = <int, double>{};
        for (final tx in txRows) {
          spendMap[tx.categoryId] =
              (spendMap[tx.categoryId] ?? 0) + tx.amount;
        }

        final result = budgetRows.map((row) {
          final budget = row.readTable(budgets);
          final cat    = row.readTable(categories);
          final spent  = spendMap[cat.id] ?? 0.0;
          return BudgetWithSpending(
            budget:   budget,
            category: cat,
            spent:    spent,
          );
        }).toList();

        result.sort((a, b) => b.pct.compareTo(a.pct));
        return result;
      },
    );
  }

  // ── watchGoals ─────────────────────────────────────────
  Stream<List<Goal>> watchGoals() {
    return (select(goals)
      ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
        .watch();
  }

  // ── watchDebts ─────────────────────────────────────────
  Stream<List<Debt>> watchDebts() {
    return (select(debts)
      ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  // ── Seed defaults ──────────────────────────────────────
  Future<void> _seedDefaults() async {
    await into(wallets).insert(WalletsCompanion.insert(
      name:    'Cash',
      balance: const Value(0),
    ));

    final expenseCategories = [
      ('Food',          '🍜', '#E8A87C'),
      ('Transport',     '⛽', '#7EC8E3'),
      ('Bills',         '📱', '#C4A778'),
      ('Groceries',     '🛒', '#95D5B2'),
      ('Housing',       '🏠', '#B8A9C9'),
      ('Entertainment', '🎮', '#F28482'),
      ('Health',        '💊', '#84DCC6'),
      ('Shopping',      '🛍️', '#FFB347'),
      ('Education',     '📚', '#87CEEB'),
      ('Other',         '📦', '#A9A9A9'),
    ];

    for (final c in expenseCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        name:      c.$1,
        type:      'EXPENSE',
        icon:      c.$2,
        color:     Value(c.$3),
        isDefault: const Value(true),
      ));
    }

    final incomeCategories = [
      ('Salary',    '💼', '#5A9E6F'),
      ('Freelance', '💻', '#5A9E6F'),
      ('Business',  '🏪', '#5A9E6F'),
      ('Other',     '💰', '#5A9E6F'),
    ];

    for (final c in incomeCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        name:      c.$1,
        type:      'INCOME',
        icon:      c.$2,
        color:     Value(c.$3),
        isDefault: const Value(true),
      ));
    }
  }
}

// ─── Connection ───────────────────────────────────────
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'katonagari.db'));
    return NativeDatabase.createInBackground(file);
  });
}
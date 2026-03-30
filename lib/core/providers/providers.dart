import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import 'package:katonagari/core/services/preferences_service.dart';

// Add this class above the provider:
class InsightsSpendingData {
  final double totalIncome;
  final double totalExpense;
  final double netFlow;
  final int savingsRate;
  final double avgDaily;
  final double avgWeekly;
  final List<CategoryStat> categoryStats;
  final List<TransactionWithCategory> top3;
  final List<int> dailyExpense; // index = day-1, value = amount

  const InsightsSpendingData({
    required this.totalIncome,
    required this.totalExpense,
    required this.netFlow,
    required this.savingsRate,
    required this.avgDaily,
    required this.avgWeekly,
    required this.categoryStats,
    required this.top3,
    required this.dailyExpense,
  });
}

class CategoryStat {
  final String name;
  final String icon;
  final String color;
  final double amount;
  final double pct;
  final bool isOneTime;
  const CategoryStat({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.pct,
    required this.isOneTime,
  });
}

final insightsSpendingProvider =
    StreamProvider<InsightsSpendingData>((ref) {
  return ref.watch(transactionsProvider.stream).map((items) {
    // Totals
    double income  = 0;
    double expense = 0;
    for (final i in items) {
      if (i.transaction.type == 'INCOME') {
        income += i.transaction.amount;
      } else {
        expense += i.transaction.amount;
      }
    }
    final net         = income - expense;
    final savingsRate = income > 0 ? ((net / income) * 100).round() : 0;

    // Days elapsed this month for averages
    final now          = DateTime.now();
    final daysElapsed  = now.day;
    final avgDaily     = daysElapsed > 0 ? expense / daysElapsed : 0.0;
    final avgWeekly    = avgDaily * 7;

    // Category breakdown (expenses only)
    final catMap = <int, double>{};
    final catInfo = <int, TransactionWithCategory>{};
    for (final i in items.where((t) => t.transaction.type == 'EXPENSE')) {
      catMap[i.category.id] =
          (catMap[i.category.id] ?? 0) + i.transaction.amount;
      catInfo[i.category.id] = i;
    }
    final catStats = catMap.entries.map((e) {
      final info = catInfo[e.key]!;
      return CategoryStat(
        name:      info.category.name,
        icon:      info.category.icon,
        color:     info.category.color,
        amount:    e.value,
        pct:       expense > 0 ? (e.value / expense * 100) : 0,
        isOneTime: false,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Top 3 biggest expense transactions
    final expenses = items
        .where((t) => t.transaction.type == 'EXPENSE')
        .toList()
      ..sort((a, b) =>
          b.transaction.amount.compareTo(a.transaction.amount));
    final top3 = expenses.take(3).toList();

    // Daily spending array (31 slots, 0-indexed by day-1)
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daily = List<int>.filled(daysInMonth, 0);
    for (final i in items.where((t) => t.transaction.type == 'EXPENSE')) {
      final day = i.transaction.date.day - 1;
      if (day >= 0 && day < daysInMonth) {
        daily[day] += i.transaction.amount.toInt();
      }
    }

    return InsightsSpendingData(
      totalIncome:  income,
      totalExpense: expense,
      netFlow:      net,
      savingsRate:  savingsRate,
      avgDaily:     avgDaily,
      avgWeekly:    avgWeekly,
      categoryStats: catStats,
      top3:          top3,
      dailyExpense:  daily,
    );
  });
});

// ── Database ──
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Repositories ──
final transactionRepoProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

final categoryRepoProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final budgetRepoProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

final walletRepoProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(databaseProvider));
});

// ── Current month ──
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ── Transactions stream ──
final transactionsProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepoProvider);
  return repo.watchWithCategoryByMonth(month.month, month.year);
});

// ── Categories stream ──
final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepoProvider).watchByType('EXPENSE');
});

final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepoProvider).watchByType('INCOME');
});

// ── Budgets stream ──
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(budgetRepoProvider)
      .watchByMonth(month.month, month.year);
});

// ── Wallet stream ──
final walletProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepoProvider).watchAll();
});

// ── Monthly totals ──
// Also update monthlyTotalsProvider to use the new type:
// WITH this:
final monthlyTotalsProvider = StreamProvider<Map<String, double>>((ref) {
  // Re-derives from the live transactions stream
  return ref.watch(transactionsProvider.stream).map((items) {
    double income = 0;
    double expense = 0;
    for (final item in items) {
      if (item.transaction.type == 'INCOME') {
        income += item.transaction.amount;
      } else {
        expense += item.transaction.amount;
      }
    }
    return {'income': income, 'expense': expense};
  });
});

final budgetsWithSpendingProvider =
    StreamProvider<List<BudgetWithSpending>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final db    = ref.watch(databaseProvider);
  return db.watchBudgetsWithSpending(
      month: month.month, year: month.year);
});

final totalBalanceProvider = StreamProvider<double>((ref) {
  return ref.watch(walletProvider.stream).map(
    (wallets) => wallets.fold(0.0, (sum, w) => sum + w.balance),
  );
});

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});
 
class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('en') {
    _load();
  }
 
  Future<void> _load() async {
    final lang = await PreferencesService.instance.getLanguage();
    state = lang;
  }
 
  Future<void> setLanguage(String lang) async {
    await PreferencesService.instance.setLanguage(lang);
    state = lang;
  }
}
 
// ── Preferences: Currency ──────────────────────────────────────────────────────
/// Holds the current currency code ('IDR', 'USD', …).
final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyInfo>((ref) {
  return CurrencyNotifier();
});
 
class CurrencyNotifier extends StateNotifier<CurrencyInfo> {
  CurrencyNotifier()
      : super(PreferencesService.supportedCurrencies.first) {
    _load();
  }
 
  Future<void> _load() async {
    final code = await PreferencesService.instance.getCurrencyCode();
    state = PreferencesService.currencyByCode(code);
  }
 
  Future<void> setCurrency(String code) async {
    await PreferencesService.instance.setCurrencyCode(code);
    state = PreferencesService.currencyByCode(code);
  }
}
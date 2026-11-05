import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:katonagari/core/providers/providers.dart';
import 'package:katonagari/data/database/app_database.dart';
import 'package:katonagari/features/dashboard/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dashboard balance only counts the selected month',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late ProviderContainer container;

    await tester.runAsync(() async {
      final wallet = (await db.select(db.wallets).get()).first.id;
      final cats   = await db.select(db.categories).get();
      int cat(String type) => cats.firstWhere((c) => c.type == type).id;

      Future<void> add(String type, double amount, DateTime date) =>
          db.into(db.transactions).insert(TransactionsCompanion.insert(
                walletId: wallet, categoryId: cat(type),
                type: type, amount: amount, date: date,
              ));

      // Last month: +5.000.000 −1.200.000 (net 3.800.000)
      await add('INCOME', 5000000, DateTime(2026, 10, 1));
      await add('EXPENSE', 1200000, DateTime(2026, 10, 15));
      // This month: only −50.000
      await add('EXPENSE', 50000, DateTime(2026, 11, 2));
    });

    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      selectedMonthProvider.overrideWith((_) => DateTime(2026, 11)),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardScreen()),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // The big balance figure on the card (36pt)
    String? balanceShown() => tester
        .widgetList<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == 36))
        .single
        .data;

    await settle();
    expect(find.text('Balance · November 2026'), findsOneWidget);
    expect(balanceShown(), '−Rp 50.000');
    expect(find.textContaining('3.800.000'), findsNothing);

    container.read(selectedMonthProvider.notifier).state = DateTime(2026, 10);
    await settle();
    expect(find.text('Balance · October 2026'), findsOneWidget);
    expect(balanceShown(), 'Rp 3.800.000');

    // Unmount first so drift's query streams are cancelled, then close the
    // database inside the fake-async zone and pump until it's done
    // (closing via runAsync deadlocks).
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    var closed = false;
    db.close().then((_) => closed = true);
    for (var i = 0; i < 20 && !closed; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(closed, isTrue);
  });
}

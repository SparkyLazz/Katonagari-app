import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/database/app_database.dart';
import 'set_budget_sheet.dart';
import '../../../core/widgets/month_picker_sheet.dart';

// ── Previous-month category spending provider ─────────────────────────────────
// Returns a map of categoryId → amount for the month BEFORE selectedMonth.
final _prevMonthCategoryProvider =
StreamProvider<Map<String, double>>((ref) {
  final selected = ref.watch(selectedMonthProvider);
  final prev     = DateTime(selected.year, selected.month - 1);
  final repo     = ref.watch(transactionRepoProvider);
  return repo
      .watchWithCategoryByMonth(prev.month, prev.year)
      .map((items) {
    final map = <String, double>{};
    for (final i in items.where((t) => t.transaction.type == 'EXPENSE')) {
      final key = i.category.name; // match by name (categories are consistent)
      map[key] = (map[key] ?? 0) + i.transaction.amount;
    }
    return map;
  });
});


class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  String _view  = 'spending';
  int    _phase = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150),
            () { if (mounted) setState(() => _phase = 1); });
    Future.delayed(const Duration(milliseconds: 300),
            () { if (mounted) setState(() => _phase = 2); });
    Future.delayed(const Duration(milliseconds: 500),
            () { if (mounted) setState(() => _phase = 3); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _view == 'spending'
                    ? _SpendingView(
                    key: const ValueKey('spending'), phase: _phase)
                    : _BudgetsView(
                    key: const ValueKey('budgets'), phase: _phase),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final selectedMonth  = ref.watch(selectedMonthProvider);
    final now            = DateTime.now();
    final isCurrentMonth = selectedMonth.year == now.year &&
        selectedMonth.month == now.month;

    return AnimatedOpacity(
      opacity:  _phase >= 1 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Insights',
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 24, color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => showMonthPicker(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentMonth
                          ? AppColors.surface
                          : AppColors.accentDim,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrentMonth
                            ? AppColors.border
                            : AppColors.accent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('MMM yyyy').format(selectedMonth),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: isCurrentMonth
                                ? AppColors.textSecondary
                                : AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: isCurrentMonth
                                ? AppColors.textMuted
                                : AppColors.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  {'id': 'spending', 'label': 'Spending', 'icon': '📊'},
                  {'id': 'budgets',  'label': 'Budgets',  'icon': '🎯'},
                ].map((v) {
                  final active = _view == v['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _view  = v['id'] as String;
                        _phase = 0;
                        Future.delayed(const Duration(milliseconds: 100),
                                () { if (mounted) setState(() => _phase = 1); });
                        Future.delayed(const Duration(milliseconds: 250),
                                () { if (mounted) setState(() => _phase = 2); });
                        Future.delayed(const Duration(milliseconds: 450),
                                () { if (mounted) setState(() => _phase = 3); });
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.accentDim
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: active
                                ? AppColors.accentMuted
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(v['icon'] as String,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              v['label'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: active
                                    ? AppColors.accent
                                    : AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── SPENDING VIEW ─────────────────────────────────────────────────────────────
class _SpendingView extends ConsumerWidget {
  final int phase;
  const _SpendingView({super.key, required this.phase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync     = ref.watch(insightsSpendingProvider);
    final prevAsync     = ref.watch(_prevMonthCategoryProvider);
    final data          = dataAsync.valueOrNull;
    final prevCatMap    = prevAsync.valueOrNull ?? {};
    final cur           = ref.currency;
    final selectedMonth = ref.watch(selectedMonthProvider);

    if (data == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (data.totalExpense == 0 && data.totalIncome == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📊', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('No data yet',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 18, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text('Add transactions to see insights',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textDim)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 100),
      children: [
        _buildSummaryStrip(phase, data, cur),
        const SizedBox(height: 14),
        _buildInsight(phase, data, cur),
        const SizedBox(height: 14),
        if (data.categoryStats.isNotEmpty) ...[
          _buildCategoryBreakdown(phase, data, cur),
          const SizedBox(height: 14),
        ],
        if (data.top3.isNotEmpty) ...[
          _buildTop3(phase, data, cur),
          const SizedBox(height: 14),
        ],
        _SpendingByCategoryTable(
          phase: phase,
          categoryStats: data.categoryStats,
          prevCatMap: prevCatMap,
          cur: cur,
          selectedMonth: selectedMonth,
        ),
        const SizedBox(height: 14),
        _BiggestMoversTable(
          phase: phase,
          categoryStats: data.categoryStats,
          prevCatMap: prevCatMap,
          cur: cur,
          selectedMonth: selectedMonth,
        ),
        const SizedBox(height: 14),
        _SpendingChart(visible: phase >= 3, daily: data.dailyExpense, cur: cur),
        const SizedBox(height: 14),
        _buildAverages(phase, data, cur),
      ],
    );
  }

  // ── Summary Strip ──────────────────────────────────────────────────────────
  Widget _buildSummaryStrip(int phase, InsightsSpendingData data, CurrencyInfo cur) {
    final items = [
      {
        'label': 'Income',
        'value': cur.formatShort(data.totalIncome),
        'color': AppColors.incomeGreen,
        'bg':    AppColors.incomeGreenDim,
        'arrow': '↑',
      },
      {
        'label': 'Expense',
        'value': cur.formatShort(data.totalExpense),
        'color': AppColors.expenseRed,
        'bg':    AppColors.expenseRedDim,
        'arrow': '↓',
      },
      {
        'label': 'Saved',
        'value': cur.formatShort(data.netFlow.abs()),
        'color': data.netFlow >= 0
            ? AppColors.incomeGreen
            : AppColors.expenseRed,
        'bg':    AppColors.surface,
        'arrow': data.netFlow >= 0 ? '✓' : '↓',
      },
    ];

    return AnimatedOpacity(
      opacity:  phase >= 1 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: s['bg'] as Color,
                    border: i < 2
                        ? Border(
                        right: BorderSide(color: AppColors.border))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${s['arrow']} ${s['label']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: s['color'] as Color,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['value'] as String,
                        style: GoogleFonts.dmMono(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: s['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Insight Card ───────────────────────────────────────────────────────────
  Widget _buildInsight(int phase, InsightsSpendingData data, CurrencyInfo cur) {
    final topCat =
    data.categoryStats.isNotEmpty ? data.categoryStats.first : null;

    return AnimatedOpacity(
      opacity:  phase >= 1 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColors.accentDim,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.accentMuted),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.savingsRate >= 0
                        ? 'Saving ${data.savingsRate}% of income this month'
                        : 'Spending exceeds income this month',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: data.savingsRate >= 0
                          ? AppColors.textPrimary
                          : AppColors.expenseRed,
                    ),
                  ),
                  if (topCat != null) ...[
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppColors.textMuted, height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Biggest spend: '),
                          TextSpan(
                            // ← was _fmtShort(topCat.amount)
                            text: '${topCat.icon} ${topCat.name} (${cur.formatShort(topCat.amount)})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                          TextSpan(
                              text: ' · ${topCat.pct.toStringAsFixed(1)}% of total'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Breakdown ─────────────────────────────────────────────────────
  Widget _buildCategoryBreakdown(int phase, InsightsSpendingData data, CurrencyInfo cur) {
    return AnimatedOpacity(
      opacity:  phase >= 2 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where it went',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...data.categoryStats.asMap().entries.map((e) {
              final i   = e.key;
              final cat = e.value;
              Color barColor;
              try {
                barColor = Color(int.parse(
                    cat.color.replaceFirst('#', 'FF'), radix: 16));
              } catch (_) {
                barColor = AppColors.accent;
              }

              return Padding(
                padding: EdgeInsets.only(
                    bottom: i < data.categoryStats.length - 1 ? 12 : 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(cat.icon,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 7),
                            Text(cat.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                )),
                          ],
                        ),
                        Row(
                          children: [
                            // ← was _fmtRp(cat.amount)
                            Text(cur.format(cat.amount),
                                style: GoogleFonts.dmMono(
                                    fontSize: 10,
                                    color: AppColors.textMuted)),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${cat.pct.toStringAsFixed(1)}%',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9, fontWeight: FontWeight.w600,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value:           (cat.pct / 100).clamp(0.0, 1.0),
                        minHeight:       5,
                        backgroundColor: AppColors.bg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            barColor.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Top 3 ──────────────────────────────────────────────────────────────────
  Widget _buildTop3(int phase, InsightsSpendingData data, CurrencyInfo cur) {
    return AnimatedOpacity(
      opacity:  phase >= 2 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biggest this month',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ...data.top3.asMap().entries.map((e) {
              final i  = e.key;
              final tx = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: i > 0
                      ? Border(
                      top: BorderSide(color: AppColors.border))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? AppColors.expenseRedDim
                            : AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: i == 0
                              ? AppColors.expenseRed.withOpacity(0.2)
                              : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 11,
                            color: i == 0
                                ? AppColors.expenseRed
                                : AppColors.textDim,
                          )),
                    ),
                    const SizedBox(width: 10),
                    Text(tx.category.icon,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.transaction.note?.isNotEmpty == true
                                ? tx.transaction.note!
                                : tx.category.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('d MMM').format(tx.transaction.date),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 9, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    // ← was '−${_fmtRp(tx.transaction.amount)}'
                    Text(
                      '−${cur.format(tx.transaction.amount)}',
                      style: GoogleFonts.dmMono(
                          fontSize: 11, color: AppColors.expenseRed),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Averages ───────────────────────────────────────────────────────────────
  Widget _buildAverages(int phase, InsightsSpendingData data, CurrencyInfo cur) {
    return AnimatedOpacity(
      opacity:  phase >= 3 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Row(
        children: [
          // ← was _fmtShort(data.avgDaily)
          Expanded(child: _AvgCard(label: 'Daily Avg',  value: cur.formatShort(data.avgDaily))),
          const SizedBox(width: 8),
          Expanded(child: _AvgCard(label: 'Weekly Avg', value: cur.formatShort(data.avgWeekly))),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAVED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8, fontWeight: FontWeight.w600,
                        color: AppColors.textDim, letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    '${data.savingsRate}%',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 16,
                      color: data.savingsRate >= 0
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spending by Category Table ────────────────────────────────────────────────
class _SpendingByCategoryTable extends StatelessWidget {
  final int              phase;
  final List<CategoryStat> categoryStats;
  final Map<String, double> prevCatMap;
  final CurrencyInfo     cur;
  final DateTime         selectedMonth;

  const _SpendingByCategoryTable({
    required this.phase,
    required this.categoryStats,
    required this.prevCatMap,
    required this.cur,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryStats.isEmpty) return const SizedBox.shrink();

    final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    final thisFmt   = DateFormat('MMM').format(selectedMonth);
    final prevFmt   = DateFormat('MMM').format(prevMonth);

    return AnimatedOpacity(
      opacity:  phase >= 3 ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  const Text('🗂️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('Spending by Category',
                      style: GoogleFonts.dmSerifDisplay(
                          fontSize: 14, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top:    BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
                color: AppColors.bg,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('Category',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.8,
                        )),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('This ($thisFmt)',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.8,
                        )),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('Prev ($prevFmt)',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.8,
                        )),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 20,
                    child: Text('▲▼',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.5,
                        )),
                  ),
                ],
              ),
            ),

            // Rows
            ...categoryStats.asMap().entries.map((e) {
              final i   = e.key;
              final cat = e.value;
              final prev  = prevCatMap[cat.name] ?? 0.0;
              final isUp  = cat.amount > prev;
              final isEq  = cat.amount == prev;
              final isLast = i == categoryStats.length - 1;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: i.isEven ? AppColors.surface : AppColors.bg,
                  borderRadius: isLast
                      ? const BorderRadius.vertical(
                      bottom: Radius.circular(14))
                      : null,
                ),
                child: Row(
                  children: [
                    // Category name
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Text(cat.icon,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(cat.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                )),
                          ),
                        ],
                      ),
                    ),
                    // This period
                    Expanded(
                      flex: 4,
                      child: Text(
                        cur.formatShort(cat.amount),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: cat.amount > 0
                              ? AppColors.expenseRed
                              : AppColors.textDim,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Prev period
                    Expanded(
                      flex: 4,
                      child: Text(
                        prev > 0 ? cur.formatShort(prev) : '—',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: prev > 0
                              ? AppColors.textMuted
                              : AppColors.textGhost,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Trend arrow
                    SizedBox(
                      width: 20,
                      child: isEq
                          ? Text('—',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: AppColors.textGhost))
                          : Icon(
                        isUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: isUp
                            ? AppColors.expenseRed
                            : AppColors.incomeGreen,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Biggest Movers Table ──────────────────────────────────────────────────────
class _BiggestMoversTable extends StatelessWidget {
  final int              phase;
  final List<CategoryStat> categoryStats;
  final Map<String, double> prevCatMap;
  final CurrencyInfo     cur;
  final DateTime         selectedMonth;

  const _BiggestMoversTable({
    required this.phase,
    required this.categoryStats,
    required this.prevCatMap,
    required this.cur,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    // Build movers: delta = this - prev, only show categories that appeared
    // in either period. Sort by absolute delta descending.
    final allNames = {
      ...categoryStats.map((c) => c.name),
      ...prevCatMap.keys,
    };

    final movers = allNames.map((name) {
      final thisCat = categoryStats.where((c) => c.name == name).firstOrNull;
      final thisPeriod = thisCat?.amount ?? 0.0;
      final prevPeriod = prevCatMap[name] ?? 0.0;
      final delta      = thisPeriod - prevPeriod;
      final pctChange  = prevPeriod > 0
          ? (delta / prevPeriod * 100)
          : (thisPeriod > 0 ? 100.0 : 0.0);
      return _MoverRow(
        icon:       thisCat?.icon ?? '📦',
        name:       name,
        delta:      delta,
        pctChange:  pctChange,
        thisPeriod: thisPeriod,
        prevPeriod: prevPeriod,
      );
    }).toList()
      ..sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));

    if (movers.isEmpty) return const SizedBox.shrink();

    final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    final thisFmt   = DateFormat('MMM').format(selectedMonth);
    final prevFmt   = DateFormat('MMM').format(prevMonth);

    return AnimatedOpacity(
      opacity:  phase >= 3 ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.expenseRed.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  const Text('📈', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Biggest Movers',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ),
                  Text('vs $prevFmt',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: AppColors.textDim,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top:    BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
                color: AppColors.bg,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('Category',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.8,
                        )),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('Δ Amount',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.8,
                        )),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Δ %',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.8,
                        )),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 20,
                    child: Text('Dir',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.textDim, letterSpacing: 0.5,
                        )),
                  ),
                ],
              ),
            ),

            // Rows
            ...movers.asMap().entries.map((e) {
              final i    = e.key;
              final m    = e.value;
              final isUp = m.delta > 0;
              final isEq = m.delta == 0;
              final isLast = i == movers.length - 1;
              final deltaColor = isEq
                  ? AppColors.textGhost
                  : isUp
                  ? AppColors.expenseRed
                  : AppColors.incomeGreen;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: i.isEven ? AppColors.surface : AppColors.bg,
                  borderRadius: isLast
                      ? const BorderRadius.vertical(
                      bottom: Radius.circular(14))
                      : null,
                ),
                child: Row(
                  children: [
                    // Category
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Text(m.icon,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(m.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                )),
                          ),
                        ],
                      ),
                    ),
                    // Delta amount
                    Expanded(
                      flex: 4,
                      child: Text(
                        isEq
                            ? '0'
                            : '${isUp ? '+' : '−'}${cur.formatShort(m.delta.abs())}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: deltaColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Delta %
                    Expanded(
                      flex: 3,
                      child: Text(
                        isEq
                            ? '0.0%'
                            : '${isUp ? '+' : ''}${m.pctChange.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: deltaColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Direction
                    SizedBox(
                      width: 20,
                      child: isEq
                          ? Text('—',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: AppColors.textGhost))
                          : Icon(
                        isUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: deltaColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MoverRow {
  final String icon, name;
  final double delta, pctChange, thisPeriod, prevPeriod;
  const _MoverRow({
    required this.icon,
    required this.name,
    required this.delta,
    required this.pctChange,
    required this.thisPeriod,
    required this.prevPeriod,
  });
}


class _AvgCard extends StatelessWidget {
  final String label, value;
  const _AvgCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 0.5,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 16, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Spending Bar Chart ────────────────────────────────────────────────────────
class _SpendingChart extends StatefulWidget {
  final bool        visible;
  final List<int>   daily;
  final CurrencyInfo cur;
  const _SpendingChart({
    required this.visible,
    required this.daily,
    required this.cur,
  });

  @override
  State<_SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<_SpendingChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(
        parent: _ctrl, curve: const Cubic(0.16, 1, 0.3, 1));
    if (widget.visible) {
      Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void didUpdateWidget(_SpendingChart old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daily    = widget.daily;
    final cur      = widget.cur;
    final avgDaily = daily.isEmpty
        ? 0.0
        : daily.reduce((a, b) => a + b) / daily.length;
    final maxVal = daily.isEmpty
        ? 1.0
        : daily.reduce((a, b) => a > b ? a : b) * 1.15;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Spending',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 14, color: AppColors.textPrimary)),
              _hoveredIndex != null
                  ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.bg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    Text('Day ${_hoveredIndex! + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                    const SizedBox(width: 6),
                    Text(
                      daily[_hoveredIndex!] > 0
                      // ← was '−${_fmtRp(...)}'
                          ? '−${cur.format(daily[_hoveredIndex!].toDouble())}'
                          : 'No spend',
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: AppColors.expenseRed),
                    ),
                  ],
                ),
              )
                  : const SizedBox(),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              return GestureDetector(
                onPanUpdate: (d) {
                  if (daily.isEmpty) return;
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final localX   = d.localPosition.dx;
                  final barWidth = box.size.width / daily.length;
                  final idx      = (localX / barWidth)
                      .floor()
                      .clamp(0, daily.length - 1);
                  setState(() => _hoveredIndex = idx);
                },
                onPanEnd:  (_) => setState(() => _hoveredIndex = null),
                onTapDown: (d) {
                  if (daily.isEmpty) return;
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final localX   = d.localPosition.dx;
                  final barWidth = box.size.width / daily.length;
                  final idx      = (localX / barWidth)
                      .floor()
                      .clamp(0, daily.length - 1);
                  setState(() => _hoveredIndex = idx);
                },
                onTapUp: (_) => setState(() => _hoveredIndex = null),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: _ChartPainter(
                      daily:        daily,
                      maxVal:       maxVal == 0 ? 1 : maxVal,
                      avgDaily:     avgDaily,
                      animValue:    _anim.value,
                      hoveredIndex: _hoveredIndex,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> daily;
  final double maxVal, avgDaily, animValue;
  final int? hoveredIndex;

  const _ChartPainter({
    required this.daily,
    required this.maxVal,
    required this.avgDaily,
    required this.animValue,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (daily.isEmpty) return;
    final chartH = size.height - 20;
    final barW   = (size.width / daily.length) - 2;
    final avgY   = 20 + chartH - (avgDaily / maxVal) * chartH;

    final gridPaint = Paint()
      ..color       = AppColors.border
      ..strokeWidth = 1;
    for (final p in [0.0, 0.5, 1.0]) {
      final y = 20 + chartH * (1 - p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < daily.length; i++) {
      final x  = (size.width / daily.length) * i +
          (size.width / daily.length - barW) / 2;
      final bH = animValue * (daily[i] / maxVal) * chartH;
      final y  = 20 + chartH - bH;
      final isHovered   = hoveredIndex == i;
      final isHighSpend = daily[i] > avgDaily * 2.5;

      Color barColor;
      if (isHovered) {
        barColor = AppColors.expenseRed;
      } else if (isHighSpend) {
        barColor = AppColors.expenseRed.withOpacity(0.55);
      } else {
        barColor = AppColors.accent.withOpacity(
            hoveredIndex != null && !isHovered ? 0.35 : 0.75);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, bH),
          const Radius.circular(3),
        ),
        Paint()..color = barColor,
      );

      if (i == 0 || (i + 1) % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text:  '${i + 1}',
            style: TextStyle(fontSize: 8, color: AppColors.textDim),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(x + barW / 2 - tp.width / 2, size.height - tp.height));
      }
    }

    if (animValue > 0 && avgDaily > 0) {
      canvas.drawLine(
        Offset(0, avgY),
        Offset(size.width, avgY),
        Paint()
          ..color       = AppColors.accent.withOpacity(0.4)
          ..strokeWidth = 1
          ..style       = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.animValue    != animValue ||
          old.hoveredIndex != hoveredIndex;
}

// ── BUDGETS VIEW ──────────────────────────────────────────────────────────────
class _BudgetsView extends ConsumerStatefulWidget {
  final int phase;
  const _BudgetsView({super.key, required this.phase});

  @override
  ConsumerState<_BudgetsView> createState() => _BudgetsViewState();
}

class _BudgetsViewState extends ConsumerState<_BudgetsView> {
  BudgetWithSpending? _selectedBudget;

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
    final budgets      = budgetsAsync.valueOrNull ?? [];
    final allCatsAsync = ref.watch(expenseCategoriesProvider);
    final allCats      = allCatsAsync.valueOrNull ?? [];
    final budgetCatIds = budgets.map((b) => b.category.id).toSet();
    final noBudgetCats =
    allCats.where((c) => !budgetCatIds.contains(c.id)).toList();
    final totalBudget  = budgets.fold(0.0, (s, b) => s + b.budget.amount);
    final totalSpent   = budgets.fold(0.0, (s, b) => s + b.spent);
    final totalPct     = totalBudget > 0
        ? (totalSpent / totalBudget * 100).round()
        : 0;
    final cur = ref.currency; // ← read once

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 100),
          children: [
            if (budgets.isNotEmpty) ...[
              AnimatedOpacity(
                opacity:  widget.phase >= 1 ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: _buildTotalSummary(
                    totalSpent, totalBudget, totalPct, cur),
              ),
              const SizedBox(height: 12),
            ],

            ...budgets.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              return AnimatedOpacity(
                opacity:  widget.phase >= 2 ? 1 : 0,
                duration: Duration(milliseconds: 300 + i * 70),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BudgetCard(
                    budget: b,
                    cur:    cur,
                    onTap:  () => setState(() => _selectedBudget = b),
                  ),
                ),
              );
            }),

            if (noBudgetCats.isNotEmpty)
              AnimatedOpacity(
                opacity:  widget.phase >= 2 ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NO BUDGET SET',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppColors.textDim, letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 8),
                    ...noBudgetCats.map((c) => Container(
                      margin:  const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color:        AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderStrong),
                      ),
                      child: Row(
                        children: [
                          Text(c.icon,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                )),
                          ),
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) =>
                                  SetBudgetSheet(category: c),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color:        AppColors.accentDim,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                    color: AppColors.accentMuted),
                              ),
                              child: Text('Set budget',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10, fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            if (budgets.isEmpty && noBudgetCats.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text('No budgets yet',
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 18, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),

        if (_selectedBudget != null)
          _BudgetDetailSheet(
            budget:  _selectedBudget!,
            cur:     cur,
            onClose: () => setState(() => _selectedBudget = null),
            onEdit:  () {
              final toEdit = _selectedBudget!;
              setState(() => _selectedBudget = null);
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => SetBudgetSheet(
                  category:       toEdit.category,
                  existingAmount: toEdit.budget.amount,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTotalSummary(
      double spent, double budget, int pct, CurrencyInfo cur) {
    final isOver = pct > 100;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL BUDGET',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: AppColors.textDim, letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // ← was _fmtShort(spent)
                      Text(cur.formatShort(spent),
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 22,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 6),
                      // ← was 'of ${_fmtShort(budget)}'
                      Text('of ${cur.formatShort(budget)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: AppColors.textDim)),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: 44, height: 44,
                child: RepaintBoundary(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(44, 44),
                        painter: _RingPainter(
                          pct:   pct,
                          color: isOver
                              ? AppColors.expenseRed
                              : AppColors.accent,
                        ),
                      ),
                      Text('$pct%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value:           (pct / 100).clamp(0.0, 1.0),
              minHeight:       5,
              backgroundColor: AppColors.bg,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct > 90 ? AppColors.expenseRed : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final int   pct;
  final Color color;
  const _RingPainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paint  = Paint()
      ..strokeWidth = 4
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = AppColors.bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * (pct / 100).clamp(0.0, 1.0),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct;
}

// ── Budget Card ───────────────────────────────────────────────────────────────
class _BudgetCard extends StatelessWidget {
  final BudgetWithSpending budget;
  final CurrencyInfo       cur;
  final VoidCallback       onTap;
  const _BudgetCard({
    required this.budget,
    required this.cur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b      = budget;
    final pct    = (b.pct * 100).round();
    final isOver = b.isOver;
    final isWarn = b.isWarn;

    Color barColor;
    try {
      barColor = Color(int.parse(
          b.category.color.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      barColor = AppColors.accent;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOver
                ? AppColors.expenseRed.withOpacity(0.2)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(b.category.icon,
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(b.category.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
                Row(
                  children: [
                    if (isOver)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        AppColors.expenseRedDim,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('OVER',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8, fontWeight: FontWeight.w700,
                              color: AppColors.expenseRed,
                            )),
                      ),
                    Text('$pct%',
                        style: GoogleFonts.dmMono(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: isOver
                              ? AppColors.expenseRed
                              : AppColors.textSecondary,
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value:           b.pct.clamp(0.0, 1.0),
                minHeight:       6,
                backgroundColor: AppColors.bg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver
                      ? AppColors.expenseRed
                      : barColor.withOpacity(isWarn ? 0.6 : 0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ← was '${_fmtRp(b.spent)} / ${_fmtRp(b.budget.amount)}'
                Text('${cur.format(b.spent)} / ${cur.format(b.budget.amount)}',
                    style: GoogleFonts.dmMono(
                        fontSize: 10, color: AppColors.textDim)),
                // ← was 'Rp ${_fmtRp(b.remaining...)} over/left'
                Text(
                  isOver
                      ? '${cur.format(b.remaining.abs())} over'
                      : '${cur.format(b.remaining)} left',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: isOver
                        ? AppColors.expenseRed
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Budget Detail Sheet ───────────────────────────────────────────────────────
class _BudgetDetailSheet extends StatefulWidget {
  final BudgetWithSpending budget;
  final CurrencyInfo       cur;
  final VoidCallback       onClose;
  final VoidCallback       onEdit;
  const _BudgetDetailSheet({
    required this.budget,
    required this.cur,
    required this.onClose,
    required this.onEdit,
  });

  @override
  State<_BudgetDetailSheet> createState() => _BudgetDetailSheetState();
}

class _BudgetDetailSheetState extends State<_BudgetDetailSheet> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b   = widget.budget;
    final cur = widget.cur;
    final pct = (b.pct * 100).round();

    return GestureDetector(
      onTap: widget.onClose,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: Colors.black.withOpacity(_show ? 0.6 : 0),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: AnimatedSlide(
              offset:   _show ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 400),
              curve:    Curves.easeOutCubic,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceEl,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color:        AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color:        AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(b.category.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.category.name,
                                  style: GoogleFonts.dmSerifDisplay(
                                      fontSize: 18,
                                      color: AppColors.textPrimary)),
                              Text(
                                DateFormat('MMMM yyyy')
                                    .format(DateTime.now()),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color:        AppColors.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.textMuted, size: 16),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:        AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SPENT',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, fontWeight: FontWeight.w600,
                                      color: AppColors.textDim,
                                      letterSpacing: 0.5,
                                    )),
                                const SizedBox(height: 3),
                                // ← was _fmtRp(b.spent)
                                Text(cur.format(b.spent),
                                    style: GoogleFonts.dmSerifDisplay(
                                      fontSize: 20,
                                      color: b.isOver
                                          ? AppColors.expenseRed
                                          : AppColors.textPrimary,
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:        AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('BUDGET',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, fontWeight: FontWeight.w600,
                                      color: AppColors.textDim,
                                      letterSpacing: 0.5,
                                    )),
                                const SizedBox(height: 3),
                                // ← was _fmtRp(b.budget.amount)
                                Text(cur.format(b.budget.amount),
                                    style: GoogleFonts.dmSerifDisplay(
                                        fontSize: 20,
                                        color: AppColors.accent)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           b.pct.clamp(0.0, 1.0),
                        minHeight:       8,
                        backgroundColor: AppColors.bg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          b.isOver
                              ? AppColors.expenseRed
                              : AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$pct% used',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: b.isOver
                                  ? AppColors.expenseRed
                                  : AppColors.textSecondary,
                            )),
                        // ← was 'Rp ${_fmtRp(b.remaining...)} over/left'
                        Text(
                          b.isOver
                              ? '${cur.format(b.remaining.abs())} over'
                              : '${cur.format(b.remaining)} left',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: b.isOver
                                ? AppColors.expenseRed
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    GestureDetector(
                      onTap: widget.onEdit,
                      child: Container(
                        width:  double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color:        AppColors.accentDim,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentMuted),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                size: 12, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text('Edit Budget',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../core/widgets/month_picker_sheet.dart';

// ─────────────────────────────────────────────────────────
//  DashboardScreen
// ─────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  late AnimationController _ctrl;
  late Animation<double> _balanceAnim;
  int    _phase       = 0;
  double _lastBalance = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _balanceAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 150),
        () { if (mounted) setState(() => _phase = 1); });
    Future.delayed(const Duration(milliseconds: 400),
        () { if (mounted) setState(() => _phase = 2); });
    Future.delayed(const Duration(milliseconds: 700),
        () { if (mounted) setState(() => _phase = 3); });
  }

  void _animateBalance(double target) {
    if (target == _lastBalance) return;
    final from   = _lastBalance;
    _lastBalance = target;
    _balanceAnim = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Map<String, List<TransactionWithCategory>> _groupTransactions(
      List<TransactionWithCategory> items) {
    final map       = <String, List<TransactionWithCategory>>{};
    final now       = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    for (final item in items.take(10)) {
      final date = item.transaction.date;
      String label;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        label = 'Today';
      } else if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        label = 'Yesterday';
      } else {
        label = DateFormat('d MMM').format(date);
      }
      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  // ─────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final txAsync      = ref.watch(transactionsProvider);
    final totalsAsync  = ref.watch(monthlyTotalsProvider);
    final balanceAsync = ref.watch(totalBalanceProvider);
    final cur          = ref.currency; // ← single read, passed everywhere

    ref.listen<AsyncValue<double>>(
      totalBalanceProvider,
      (_, next) => _animateBalance(next.valueOrNull ?? 0.0),
    );

    final transactions = txAsync.valueOrNull ?? <TransactionWithCategory>[];
    final totals       = totalsAsync.valueOrNull ?? {'income': 0.0, 'expense': 0.0};
    final totalIncome  = totals['income']  ?? 0.0;
    final totalExpense = totals['expense'] ?? 0.0;
    final balance      = balanceAsync.valueOrNull ?? 0.0;
    final isLoading    = txAsync.isLoading || totalsAsync.isLoading || balanceAsync.isLoading;

    final today = DateTime.now();
    final todaySpent = transactions
        .where((t) =>
            t.transaction.type == 'EXPENSE' &&
            t.transaction.date.year  == today.year &&
            t.transaction.date.month == today.month &&
            t.transaction.date.day   == today.day)
        .fold(0.0, (s, t) => s + t.transaction.amount);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(todaySpent, cur)),
            SliverToBoxAdapter(
                child: _buildBalanceCard(
                    balance, totalIncome, totalExpense, isLoading, cur)),
            SliverToBoxAdapter(child: _buildBudgetSection(cur)),
            SliverToBoxAdapter(child: _buildRecentSection(transactions)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(double todaySpent, CurrencyInfo cur) {
    final now           = DateTime.now();
    final dateStr       = DateFormat('EEEE, d MMMM').format(now);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final isCurrentMonth = selectedMonth.year == now.year &&
        selectedMonth.month == now.month;

    return AnimatedOpacity(
      opacity:  _phase >= 1 ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset:   _phase >= 1 ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 400),
        curve:    Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      )),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('Today  ',
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 14, color: AppColors.textSecondary)),
                      Text(
                        todaySpent > 0
                            ? '−${cur.format(todaySpent)}'
                            : 'No spending yet',
                        style: GoogleFonts.dmMono(
                            fontSize: 15,
                            color: todaySpent > 0
                                ? AppColors.expenseRed
                                : AppColors.textDim),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => showMonthPicker(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        ),
      ),
    );
  }

  // ── Balance Card ─────────────────────────────────────────────────────────────
  Widget _buildBalanceCard(double balance, double totalIncome,
      double totalExpense, bool isLoading, CurrencyInfo cur) {
    return AnimatedOpacity(
      opacity:  _phase >= 1 ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSlide(
        offset:   _phase >= 1 ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 500),
        curve:    Curves.easeOutCubic,
        child: Container(
          margin:  const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border:       Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40, right: -40,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Balance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AppColors.textMuted, letterSpacing: 0.5,
                      )),

                  const SizedBox(height: 10),

                  isLoading
                      ? Container(
                          width: 180, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceEl,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _balanceAnim,
                          builder: (_, __) {
                            final val   = _balanceAnim.value;
                            final isNeg = val < 0;
                            return Text(
                              '${isNeg ? "−" : ""}${cur.format(val.abs())}',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 36,
                                color: isNeg
                                    ? AppColors.expenseRed
                                    : AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _StatPill(
                        icon:   Icons.arrow_upward_rounded,
                        amount: totalIncome,
                        color:  AppColors.incomeGreen,
                        bg:     AppColors.incomeGreenDim,
                        cur:    cur,
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon:   Icons.arrow_downward_rounded,
                        amount: totalExpense,
                        color:  AppColors.expenseRed,
                        bg:     AppColors.expenseRedDim,
                        cur:    cur,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Budget Section ────────────────────────────────────────────────────────────
  Widget _buildBudgetSection(CurrencyInfo cur) {
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
    final budgets      = budgetsAsync.valueOrNull ?? [];

    return AnimatedOpacity(
      opacity:  _phase >= 2 ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budgets',
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 17, color: AppColors.textPrimary)),
                Text('See all →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    )),
              ],
            ),
            const SizedBox(height: 14),

            if (budgets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No budgets set',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              )),
                          Text('Go to Insights → Budgets to set one',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppColors.textDim)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...budgets.take(3).toList().asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RealBudgetCard(
                    data:    e.value,
                    visible: _phase >= 2,
                    delay:   Duration(milliseconds: 100 + e.key * 100),
                    cur:     cur,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Recent Transactions ───────────────────────────────────────────────────────
  Widget _buildRecentSection(List<TransactionWithCategory> transactions) {
    final grouped = _groupTransactions(transactions);

    return AnimatedOpacity(
      opacity:  _phase >= 3 ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent',
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 17, color: AppColors.textPrimary)),
                Text('See all →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    )),
              ],
            ),
            const SizedBox(height: 10),

            if (transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No transactions yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              )),
                          Text('Tap + to add your first one',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppColors.textDim)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...grouped.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text(entry.key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppColors.textDim, letterSpacing: 0.5,
                            )),
                      ),
                      ...entry.value.map((item) => _TxRowFromDb(
                            item: item,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => TxDetailSheet(tx: {
                                'icon':     item.category.icon,
                                'name':     item.transaction.note?.isNotEmpty == true
                                                ? item.transaction.note!
                                                : item.category.name,
                                'cat':      item.category.name,
                                'amount':   item.transaction.type == 'INCOME'
                                                ? item.transaction.amount
                                                : -item.transaction.amount,
                                'date':     item.transaction.date
                                                .toIso8601String()
                                                .split('T')[0],
                                'time':     DateFormat('HH:mm')
                                                .format(item.transaction.date),
                                'note':     item.transaction.note ?? '',
                                'oneTime':  item.transaction.isOneTime,
                                'walletId': item.transaction.walletId,
                              }),
                            ),
                          )),
                    ],
                  )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Stat Pill  — ConsumerWidget so it reads currencyProvider
// ─────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData     icon;
  final double       amount;
  final Color        color, bg;
  final CurrencyInfo cur;

  const _StatPill({
    required this.icon,
    required this.amount,
    required this.color,
    required this.bg,
    required this.cur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            cur.format(amount),
            style: GoogleFonts.dmMono(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Transaction Row — ConsumerWidget to read currencyProvider
// ─────────────────────────────────────────────────────────
class _TxRowFromDb extends ConsumerWidget {
  final TransactionWithCategory item;
  final VoidCallback onTap;
  const _TxRowFromDb({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur      = ref.currency;
    final tx       = item.transaction;
    final cat      = item.category;
    final isIncome = tx.type == 'INCOME';
    final absAmt   = tx.amount;
    final isLarge  = absAmt >= 1000000;
    final isMedium = absAmt >= 100000 && absAmt < 1000000;
    final iconSize   = isLarge ? 44.0 : 38.0;
    final amountSize = isLarge ? 14.0 : isMedium ? 12.0 : 11.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color:   Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: isLarge ? 6.0 : 4.0),
        child: Row(
          children: [
            Container(
              width:  iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: isLarge
                    ? (isIncome
                        ? AppColors.incomeGreenDim
                        : AppColors.expenseRedDim)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(isLarge ? 14 : 11),
                border: Border.all(
                  color: isLarge
                      ? (isIncome
                          ? AppColors.incomeGreen.withOpacity(0.2)
                          : AppColors.expenseRed.withOpacity(0.2))
                      : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(cat.icon,
                  style: TextStyle(fontSize: isLarge ? 22 : 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tx.note?.isNotEmpty == true ? tx.note! : cat.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   isLarge ? 14 : 13,
                  fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
                  color:      AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? "+" : "−"}${cur.format(absAmt)}',
                  style: GoogleFonts.dmMono(
                    fontSize:   amountSize,
                    fontWeight: isLarge ? FontWeight.w500 : FontWeight.w400,
                    color: isIncome
                        ? AppColors.incomeGreen
                        : AppColors.expenseRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(DateFormat('HH:mm').format(tx.date),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: AppColors.textDim)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Transaction Detail Sheet
// ─────────────────────────────────────────────────────────
class TxDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> tx;
  const TxDetailSheet({super.key, required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur       = ref.currency;
    final amount    = tx['amount'] as double;
    final isIncome  = amount > 0;
    final absAmt    = amount.abs();
    final isOneTime = tx['oneTime'] == true;
    final date      = DateTime.parse(tx['date'] as String);
    final dateStr   = '${date.day} ${_monthName(date.month)} ${date.year}';

    final wallets    = ref.watch(walletProvider).valueOrNull ?? [];
    final walletId   = tx['walletId'] as int?;
    final walletName = wallets
        .where((w) => w.id == walletId)
        .map((w) => '${w.icon} ${w.name}')
        .firstOrNull ?? '—';

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon + name + tag
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Text(tx['icon'] as String,
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['name'] as String,
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 18, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(tx['cat'] as String,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppColors.textMuted)),
                        if (isOneTime) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:        AppColors.accentDim,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('ONE-TIME',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8, fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                )),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Amount — uses live currency
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${isIncome ? "+" : "−"}${cur.format(absAmt)}',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 32,
                color: isIncome ? AppColors.incomeGreen : AppColors.expenseRed,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Detail grid
          GridView.count(
            crossAxisCount:   2,
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing:  10,
            childAspectRatio: 2.8,
            children: [
              DetailCell(label: 'Date',    value: dateStr),
              DetailCell(label: 'Time',    value: tx['time'] as String),
              DetailCell(label: 'Type',    value: isIncome ? 'Income' : 'Expense'),
              DetailCell(label: 'Account', value: walletName),
            ],
          ),

          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text('Edit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color:  AppColors.expenseRedDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.expenseRed.withOpacity(0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text('Delete',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.expenseRed,
                      )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

// ─────────────────────────────────────────────────────────
//  Detail Cell
// ─────────────────────────────────────────────────────────
class DetailCell extends StatelessWidget {
  final String label, value;
  const DetailCell({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:  MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9, fontWeight: FontWeight.w500,
                color: AppColors.textDim, letterSpacing: 0.5,
              )),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Budget Card — receives cur from parent
// ─────────────────────────────────────────────────────────
class _RealBudgetCard extends StatefulWidget {
  final BudgetWithSpending data;
  final bool               visible;
  final Duration           delay;
  final CurrencyInfo       cur;

  const _RealBudgetCard({
    required this.data,
    required this.visible,
    required this.delay,
    required this.cur,
  });

  @override
  State<_RealBudgetCard> createState() => _RealBudgetCardState();
}

class _RealBudgetCardState extends State<_RealBudgetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _barAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _barAnim = CurvedAnimation(
        parent: _ctrl, curve: const Cubic(0.16, 1, 0.3, 1));
    if (widget.visible) {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void didUpdateWidget(_RealBudgetCard old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b        = widget.data;
    final cur      = widget.cur;
    final pct      = (b.pct * 100).round();
    final barColor = b.isOver ? AppColors.expenseRed : AppColors.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: b.isOver
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
              Text('$pct%',
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    color: b.isOver
                        ? AppColors.expenseRed
                        : AppColors.textMuted,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) => LinearProgressIndicator(
                  value:           (b.pct * _barAnim.value).clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  valueColor:      AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cur.format(b.spent)} spent',
                style: GoogleFonts.dmMono(
                    fontSize: 10, color: AppColors.textMuted),
              ),
              Text(
                'of ${cur.format(b.budget.amount)}',
                style: GoogleFonts.dmMono(
                    fontSize: 10, color: AppColors.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
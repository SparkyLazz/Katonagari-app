import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';
import 'add_debt_sheet.dart';

// ─────────────────────────────────────────────────────
//  DebtScreen
// ─────────────────────────────────────────────────────
class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  String _tab = 'OWE'; // 'OWE' | 'OWED'
  int _phase  = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100),
            () { if (mounted) setState(() => _phase = 1); });
    Future.delayed(const Duration(milliseconds: 300),
            () { if (mounted) setState(() => _phase = 2); });
  }

  void _openAddSheet() async {
    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => const AddDebtSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cur      = ref.currency;
    final debtsAsync = ref.watch(debtsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity:  _phase >= 1 ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: Text('Debts',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 28, color: AppColors.textPrimary)),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity:  _phase >= 1 ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: GestureDetector(
                      onTap: _openAddSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color:        AppColors.accentDim,
                          borderRadius: BorderRadius.circular(10),
                          border:       Border.all(color: AppColors.accentMuted),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text('Add',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Content ─────────────────────────────────
            Expanded(
              child: debtsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMuted))),
                data: (allDebts) {
                  final oweList  = allDebts.where((d) => d.type == 'OWE').toList();
                  final owedList = allDebts.where((d) => d.type == 'OWED').toList();

                  final oweTotal  = oweList
                      .where((d) => !d.isPaid)
                      .fold(0.0, (s, d) => s + d.amount);
                  final owedTotal = owedList
                      .where((d) => !d.isPaid)
                      .fold(0.0, (s, d) => s + d.amount);

                  final activeList = _tab == 'OWE' ? oweList : owedList;

                  return CustomScrollView(
                    slivers: [
                      // Summary card
                      SliverToBoxAdapter(
                        child: AnimatedOpacity(
                          opacity:  _phase >= 1 ? 1 : 0,
                          duration: const Duration(milliseconds: 400),
                          child: _SummaryCard(
                            oweTotal:  oweTotal,
                            owedTotal: owedTotal,
                            cur:       cur,
                          ),
                        ),
                      ),

                      // Tab row
                      SliverToBoxAdapter(
                        child: AnimatedOpacity(
                          opacity:  _phase >= 1 ? 1 : 0,
                          duration: const Duration(milliseconds: 400),
                          child: _TabBar(
                            active:       _tab,
                            oweCount:     oweList.where((d) => !d.isPaid).length,
                            owedCount:    owedList.where((d) => !d.isPaid).length,
                            onChanged:    (t) => setState(() => _tab = t),
                          ),
                        ),
                      ),

                      // Empty state
                      if (activeList.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tab == 'OWE' ? '💸' : '🤝',
                                  style: const TextStyle(fontSize: 40),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _tab == 'OWE'
                                      ? 'No Debt recorded'
                                      : 'No Claim recorded',
                                  style: GoogleFonts.dmSerifDisplay(
                                      fontSize: 18,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap + Add to record one',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.textDim),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                final debt = activeList[i];
                                return AnimatedOpacity(
                                  opacity:  _phase >= 2 ? 1 : 0,
                                  duration: Duration(
                                      milliseconds: 300 + i * 60),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _DebtCard(
                                      debt: debt,
                                      cur:  cur,
                                      tab:  _tab,
                                    ),
                                  ),
                                );
                              },
                              childCount: activeList.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Summary Card
// ─────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double oweTotal, owedTotal;
  final CurrencyInfo cur;

  const _SummaryCard({
    required this.oweTotal,
    required this.owedTotal,
    required this.cur,
  });

  @override
  Widget build(BuildContext context) {
    final net = owedTotal - oweTotal;
    final isPositive = net >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Net position
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net Position',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.textDim,
                            letterSpacing: 0.5,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        '${isPositive ? '+' : '−'}${cur.format(net.abs())}',
                        style: GoogleFonts.dmMono(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: isPositive
                              ? AppColors.incomeGreen
                              : AppColors.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isPositive ? '🟢' : '🔴',
                  style: const TextStyle(fontSize: 28),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            // Owe vs Owed pills
            Row(
              children: [
                Expanded(
                  child: _SummaryPill(
                    label:  'I Owe',
                    amount: oweTotal,
                    color:  AppColors.expenseRed,
                    bg:     AppColors.expenseRedDim,
                    cur:    cur,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryPill(
                    label:  'Owed to Me',
                    amount: owedTotal,
                    color:  AppColors.incomeGreen,
                    bg:     AppColors.incomeGreenDim,
                    cur:    cur,
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

class _SummaryPill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color, bg;
  final CurrencyInfo cur;

  const _SummaryPill({
    required this.label,
    required this.amount,
    required this.color,
    required this.bg,
    required this.cur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              )),
          const SizedBox(height: 2),
          Text(cur.format(amount),
              style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Tab Bar
// ─────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final String active;
  final int oweCount, owedCount;
  final ValueChanged<String> onChanged;

  const _TabBar({
    required this.active,
    required this.oweCount,
    required this.owedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _Tab(
              label:   'Debt',
              emoji:   '💸',
              sub:     'I owe',
              count:   oweCount,
              active:  active == 'OWE',
              color:   AppColors.expenseRed,
              dimColor: AppColors.expenseRedDim,
              onTap:   () => onChanged('OWE'),
            ),
            _Tab(
              label:   'Claim',
              emoji:   '🤝',
              sub:     'Owed to me',
              count:   owedCount,
              active:  active == 'OWED',
              color:   AppColors.incomeGreen,
              dimColor: AppColors.incomeGreenDim,
              onTap:   () => onChanged('OWED'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label, emoji, sub;
  final int    count;
  final bool   active;
  final Color  color, dimColor;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.emoji,
    required this.sub,
    required this.count,
    required this.active,
    required this.color,
    required this.dimColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color:        active ? dimColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: active ? color : AppColors.textMuted,
                      )),
                  Text(sub,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, color: AppColors.textDim)),
                ],
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        active ? color.withOpacity(0.18) : AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: GoogleFonts.dmMono(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: active ? color : AppColors.textDim,
                      )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Debt Card
// ─────────────────────────────────────────────────────
class _DebtCard extends ConsumerWidget {
  final Debt       debt;
  final CurrencyInfo cur;
  final String     tab;

  const _DebtCard({
    required this.debt,
    required this.cur,
    required this.tab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaid   = debt.isPaid;
    final isOwe    = debt.type == 'OWE';
    final accentC  = isOwe ? AppColors.expenseRed : AppColors.incomeGreen;
    final accentDim = isOwe ? AppColors.expenseRedDim : AppColors.incomeGreenDim;

    final now      = DateTime.now();
    final isOverdue = debt.dueDate != null &&
        debt.dueDate!.isBefore(now) &&
        !isPaid;
    final isDueSoon = debt.dueDate != null &&
        !isOverdue &&
        debt.dueDate!.isBefore(now.add(const Duration(days: 3))) &&
        !isPaid;

    return AnimatedOpacity(
      opacity:  isPaid ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue
                ? AppColors.expenseRed.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji avatar
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color:        isPaid ? AppColors.bg : accentDim,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(
                          color: isPaid
                              ? AppColors.border
                              : accentC.withOpacity(0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isPaid ? '✅' : (isOwe ? '💸' : '🤝'),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            decoration: isPaid
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (debt.dueDate != null) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: isOverdue
                                    ? AppColors.expenseRed
                                    : isDueSoon
                                    ? Colors.orange
                                    : AppColors.textDim,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat('d MMM yyyy').format(debt.dueDate!),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isOverdue
                                      ? AppColors.expenseRed
                                      : isDueSoon
                                      ? Colors.orange
                                      : AppColors.textDim,
                                  fontWeight: isOverdue || isDueSoon
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              if (isOverdue) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color:        AppColors.expenseRedDim,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('OVERDUE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.expenseRed,
                                        letterSpacing: 0.5,
                                      )),
                                ),
                              ],
                            ] else
                              Text('No due date',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.textGhost)),
                          ],
                        ),
                        if (debt.note != null && debt.note!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            debt.note!,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textDim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        cur.format(debt.amount),
                        style: GoogleFonts.dmMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isPaid
                              ? AppColors.textDim
                              : accentC,
                          decoration: isPaid
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 4),
                        Text('Paid',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.incomeGreen,
                            )),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.border)),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  // Mark paid / unpaid
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await ref.read(debtRepoProvider).markPaid(
                          debt,
                          paid: !isPaid,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 14,
                              color: isPaid
                                  ? AppColors.textDim
                                  : AppColors.incomeGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPaid ? 'Mark Unpaid' : 'Mark Paid',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isPaid
                                    ? AppColors.textDim
                                    : AppColors.incomeGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1, height: 24,
                    color: AppColors.border,
                  ),

                  // Delete
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            title: Text('Delete this?',
                                style: GoogleFonts.dmSerifDisplay(
                                    color: AppColors.textPrimary)),
                            content: Text(
                              'Remove debt with ${debt.personName}?',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: Text('Cancel',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.textMuted)),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: Text('Delete',
                                    style: GoogleFonts.plusJakartaSans(
                                      color:      AppColors.expenseRed,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          HapticFeedback.mediumImpact();
                          await ref
                              .read(debtRepoProvider)
                              .delete(debt.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 14,
                                color: AppColors.expenseRed),
                            const SizedBox(width: 6),
                            Text('Delete',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.expenseRed,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
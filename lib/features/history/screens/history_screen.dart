import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/database/app_database.dart';
import '../../dashboard/screens/dashboard_screen.dart' show TxDetailSheet;
import 'package:drift/drift.dart' show Value;
import '../../../core/widgets/month_picker_sheet.dart';

Value<T> drift_value<T>(T? val) =>
    val != null ? Value(val) : const Value.absent();

String _dateLabel(DateTime d) {
  final now       = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'Today';
  } else if (d.year == yesterday.year &&
      d.month == yesterday.month &&
      d.day == yesterday.day) {
    return 'Yesterday';
  }
  return DateFormat('EEE, d MMM').format(d);
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  bool _searchFocused = false;
  String _typeFilter  = 'all';
  String? _dateRangeLabel;
  String? _dateStart;
  String? _dateEnd;

  List<TransactionWithCategory>? _cachedFiltered;
  String? _lastQuery;
  String? _lastType;
  String? _lastStart;
  String? _lastEnd;
  int?    _lastTxCount;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransactionWithCategory> _getFiltered(
      List<TransactionWithCategory> all) {
    final query = _searchCtrl.text;
    if (_cachedFiltered != null &&
        _lastQuery    == query &&
        _lastType     == _typeFilter &&
        _lastStart    == _dateStart &&
        _lastEnd      == _dateEnd &&
        _lastTxCount  == all.length) {
      return _cachedFiltered!;
    }
    _lastQuery   = query;
    _lastType    = _typeFilter;
    _lastStart   = _dateStart;
    _lastEnd     = _dateEnd;
    _lastTxCount = all.length;
    _cachedFiltered = _filtered(all);
    return _cachedFiltered!;
  }

  List<TransactionWithCategory> _filtered(
      List<TransactionWithCategory> all) {
    return all.take(200).where((item) {
      final tx = item.transaction;
      if (_typeFilter == 'income'  && tx.type != 'INCOME')  return false;
      if (_typeFilter == 'expense' && tx.type != 'EXPENSE') return false;
      if (_dateStart != null) {
        final start = DateTime.parse(_dateStart!);
        if (tx.date.isBefore(start)) return false;
      }
      if (_dateEnd != null) {
        final end = DateTime.parse(_dateEnd!).add(const Duration(days: 1));
        if (tx.date.isAfter(end)) return false;
      }
      final q = _searchCtrl.text.toLowerCase();
      if (q.isNotEmpty) {
        return item.category.name.toLowerCase().contains(q) ||
            (tx.note ?? '').toLowerCase().contains(q) ||
            tx.amount.toString().contains(q);
      }
      return true;
    }).toList();
  }

  Map<String, List<TransactionWithCategory>> _grouped(
      List<TransactionWithCategory> items) {
    final map = <String, List<TransactionWithCategory>>{};
    for (final item in items) {
      final label = _dateLabel(item.transaction.date);
      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  Future<void> _deleteTransaction(TransactionWithCategory item) async {
    final tx           = item.transaction;
    final walletRepo   = ref.read(walletRepoProvider);
    final reverseDelta = tx.type == 'INCOME' ? -tx.amount : tx.amount;
    await walletRepo.adjustBalance(tx.walletId, reverseDelta);
    await ref.read(transactionRepoProvider).delete(tx.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: AppColors.surfaceEl,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.borderStrong),
          ),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.close_rounded,
                  color: AppColors.expenseRed, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item.category.name} deleted',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DateRangeSheet(
        currentStart: _dateStart,
        currentEnd:   _dateEnd,
        currentLabel: _dateRangeLabel,
        onApply: (start, end, label) => setState(() {
          _dateStart      = start;
          _dateEnd        = end;
          _dateRangeLabel = label;
          _cachedFiltered = null;
        }),
        onClear: () => setState(() {
          _dateStart      = null;
          _dateEnd        = null;
          _dateRangeLabel = null;
          _cachedFiltered = null;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allAsync = ref.watch(transactionsProvider);
    final cur      = ref.currency; // ← read once, passed down

    if (allAsync.hasError) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text('Something went wrong',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 18, color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Text('Pull to refresh',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: AppColors.textDim)),
            ],
          ),
        ),
      );
    }

    final all      = allAsync.valueOrNull ?? [];
    final filtered = _getFiltered(all);
    final grouped  = _grouped(filtered);

    final incomeTotal = filtered
        .where((i) => i.transaction.type == 'INCOME')
        .fold(0.0, (s, i) => s + i.transaction.amount);
    final expenseTotal = filtered
        .where((i) => i.transaction.type == 'EXPENSE')
        .fold(0.0, (s, i) => s + i.transaction.amount);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSummaryStrip(incomeTotal, expenseTotal, filtered.length, cur),
            Expanded(
              child: grouped.isEmpty
                  ? _buildEmptyState()
                  : _buildList(grouped, cur),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final selectedMonth  = ref.watch(selectedMonthProvider);
    final now            = DateTime.now();
    final isCurrentMonth = selectedMonth.year == now.year &&
        selectedMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('History',
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

          const SizedBox(height: 16),

          // Search bar
          Focus(
            onFocusChange: (f) => setState(() => _searchFocused = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchFocused ? AppColors.accent : AppColors.border,
                  width: _searchFocused ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search_rounded,
                        size: 18,
                        color: _searchFocused
                            ? AppColors.accent
                            : AppColors.textDim),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) {
                        _cachedFiltered = null;
                        setState(() {});
                      },
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textDim),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _cachedFiltered = null;
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...['all', 'expense', 'income'].map((f) {
                  final active = _typeFilter == f;
                  final label  = f == 'all'
                      ? 'All'
                      : f == 'expense'
                          ? 'Expense'
                          : 'Income';
                  return GestureDetector(
                    onTap: () {
                      _cachedFiltered = null;
                      setState(() => _typeFilter = f);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.accentDim
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: active
                              ? AppColors.accent
                              : AppColors.border,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Text(label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500,
                            color: active
                                ? AppColors.accent
                                : AppColors.textMuted,
                          )),
                    ),
                  );
                }),

                // Date range chip
                GestureDetector(
                  onTap: _showDatePicker,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _dateRangeLabel != null
                          ? AppColors.accentDim
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: _dateRangeLabel != null
                            ? AppColors.accent
                            : AppColors.border,
                        width: _dateRangeLabel != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12,
                            color: _dateRangeLabel != null
                                ? AppColors.accent
                                : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          _dateRangeLabel ?? 'Date Range',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: _dateRangeLabel != null
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: _dateRangeLabel != null
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                        if (_dateRangeLabel != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() {
                              _dateStart      = null;
                              _dateEnd        = null;
                              _dateRangeLabel = null;
                              _cachedFiltered = null;
                            }),
                            child: Icon(Icons.close_rounded,
                                size: 12, color: AppColors.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Summary Strip ─────────────────────────────────────────────────────────────
  Widget _buildSummaryStrip(
      double income, double expense, int count, CurrencyInfo cur) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Row(
        children: [
          _SummaryPill(
            icon:   Icons.arrow_upward_rounded,
            amount: income,
            color:  AppColors.incomeGreen,
            bg:     AppColors.incomeGreenDim,
            cur:    cur,
          ),
          const SizedBox(width: 10),
          _SummaryPill(
            icon:   Icons.arrow_downward_rounded,
            amount: expense,
            color:  AppColors.expenseRed,
            bg:     AppColors.expenseRedDim,
            cur:    cur,
          ),
          const Spacer(),
          Text('$count transactions',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.textDim)),
        ],
      ),
    );
  }

  // ── Transaction List ──────────────────────────────────────────────────────────
  Widget _buildList(
      Map<String, List<TransactionWithCategory>> grouped, CurrencyInfo cur) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: grouped.length,
      itemBuilder: (_, gi) {
        final entry  = grouped.entries.elementAt(gi);
        final label  = entry.key;
        final items  = entry.value;

        final net = items.fold(
            0.0,
            (s, i) => s +
                (i.transaction.type == 'INCOME'
                    ? i.transaction.amount
                    : -i.transaction.amount));
        final netColor =
            net >= 0 ? AppColors.incomeGreen : AppColors.expenseRed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.textDim, letterSpacing: 0.5,
                      )),
                  // ← was '${net >= 0 ? "+" : "−"}Rp ${_fmtRp(net)}'
                  Text(
                    '${net >= 0 ? "+" : "−"}${cur.format(net.abs())}',
                    style: GoogleFonts.dmMono(
                        fontSize: 10, color: netColor),
                  ),
                ],
              ),
            ),
            ...items.map((item) => _SwipeableTxRow(
                  item:     item,
                  cur:      cur,
                  onTap:    () => showModalBottomSheet(
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
                  onDelete: () => _deleteTransaction(item),
                )),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No transactions found',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 18, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text('Try adjusting your filters',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

// ── Summary Pill ─────────────────────────────────────────────────────────────
class _SummaryPill extends StatelessWidget {
  final IconData     icon;
  final double       amount;
  final Color        color, bg;
  final CurrencyInfo cur;

  const _SummaryPill({
    required this.icon,
    required this.amount,
    required this.color,
    required this.bg,
    required this.cur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          // ← was _fmtRp(amount)
          Text(cur.format(amount),
              style: GoogleFonts.dmMono(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ── Swipeable Row ─────────────────────────────────────────────────────────────
class _SwipeableTxRow extends StatefulWidget {
  final TransactionWithCategory item;
  final CurrencyInfo             cur;
  final VoidCallback             onTap;
  final VoidCallback             onDelete;

  const _SwipeableTxRow({
    required this.item,
    required this.cur,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_SwipeableTxRow> createState() => _SwipeableTxRowState();
}

class _SwipeableTxRowState extends State<_SwipeableTxRow> {
  double _offsetX   = 0;
  bool _showConfirm = false;

  @override
  Widget build(BuildContext context) {
    final tx        = widget.item.transaction;
    final cat       = widget.item.category;
    final cur       = widget.cur;
    final isIncome  = tx.type == 'INCOME';
    final absAmt    = tx.amount;
    final isLarge   = absAmt >= 1000000;
    final isMed     = absAmt >= 100000;
    final isOneTime = tx.isOneTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Delete background
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 100,
                  color: _showConfirm
                      ? AppColors.expenseRed
                      : AppColors.expenseRedDim,
                  child: _showConfirm
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Delete',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.expenseRed,
                                    )),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => setState(() {
                                _showConfirm = false;
                                _offsetX     = 0;
                              }),
                              child: Text('Cancel',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.7),
                                  )),
                            ),
                          ],
                        )
                      : const Icon(Icons.delete_outline_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ),

            // Row content
            GestureDetector(
              onHorizontalDragUpdate: (d) {
                if (d.delta.dx < 0) {
                  setState(() {
                    _offsetX = (_offsetX + d.delta.dx).clamp(-100.0, 0.0);
                  });
                }
              },
              onHorizontalDragEnd: (_) {
                if (_offsetX < -60) {
                  setState(() {
                    _showConfirm = true;
                    _offsetX     = -90;
                  });
                } else {
                  setState(() {
                    _offsetX     = 0;
                    _showConfirm = false;
                  });
                }
              },
              onTap: () {
                if (_offsetX.abs() < 5 && !_showConfirm) widget.onTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(_offsetX, 0, 0),
                padding: EdgeInsets.symmetric(
                    horizontal: 14, vertical: isLarge ? 14 : 11),
                decoration: BoxDecoration(color: AppColors.bg),
                child: Row(
                  children: [
                    Container(
                      width:  isLarge ? 42 : 38,
                      height: isLarge ? 42 : 38,
                      decoration: BoxDecoration(
                        color: isLarge
                            ? (isIncome
                                ? AppColors.incomeGreenDim
                                : AppColors.expenseRedDim)
                            : AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(isLarge ? 13 : 10),
                        border: Border.all(
                          color: isLarge
                              ? (isIncome
                                  ? AppColors.incomeGreen.withOpacity(0.2)
                                  : AppColors.expenseRed.withOpacity(0.15))
                              : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(cat.icon,
                          style: TextStyle(fontSize: isLarge ? 19 : 16)),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.note?.isNotEmpty == true
                                ? tx.note!
                                : cat.name,
                            style: isLarge
                                ? GoogleFonts.dmSerifDisplay(
                                    fontSize: 14,
                                    color: AppColors.textPrimary)
                                : GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(cat.name,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.textDim)),
                              if (isOneTime) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentDim,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text('ONE-TIME',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                      )),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // ← was '${isIncome ? "+" : "−"}${_fmtRp(absAmt)}'
                        Text(
                          '${isIncome ? "+" : "−"}${cur.format(absAmt)}',
                          style: GoogleFonts.dmMono(
                            fontSize: isLarge ? 14 : isMed ? 12 : 11,
                            fontWeight: isLarge
                                ? FontWeight.w500
                                : FontWeight.w400,
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
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Range Sheet ──────────────────────────────────────────────────────────
class _DateRangeSheet extends StatefulWidget {
  final String? currentStart;
  final String? currentEnd;
  final String? currentLabel;
  final Function(String, String, String) onApply;
  final VoidCallback onClear;
  const _DateRangeSheet({
    required this.currentStart,
    required this.currentEnd,
    required this.currentLabel,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  String? _startDate;
  String? _endDate;
  bool    _showCustom = false;
  String  _editing    = 'start';
  int     _calMonth   = DateTime.now().month;
  int     _calYear    = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _startDate = widget.currentStart;
    _endDate   = widget.currentEnd;
  }

  void _applyPreset(String label, DateTime start, DateTime end) {
    final fmt = DateFormat('yyyy-MM-dd');
    widget.onApply(fmt.format(start), fmt.format(end), label);
    Navigator.pop(context);
  }

  void _applyCustom() {
    if (_startDate == null || _endDate == null) return;
    final start = DateTime.parse(_startDate!);
    final end   = DateTime.parse(_endDate!);
    final diff  = end.difference(start).inDays + 1;
    final label =
        '${DateFormat('d MMM').format(start)} → ${DateFormat('d MMM').format(end)} · $diff days';
    widget.onApply(_startDate!, _endDate!, label);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final now     = DateTime.now();
    final wkStart = now.subtract(Duration(days: now.weekday - 1));
    final moStart = DateTime(now.year, now.month, 1);
    final yrStart = DateTime(now.year, 1, 1);
    final fmt     = DateFormat('d MMM');

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Date Range',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 18, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing:  10,
              childAspectRatio: 2.8,
              children: [
                _PresetTile(
                  label: 'Today',
                  sub:   fmt.format(now),
                  onTap: () => _applyPreset('Today', now, now),
                ),
                _PresetTile(
                  label: 'This Week',
                  sub:   '${fmt.format(wkStart)} – ${fmt.format(now)}',
                  onTap: () => _applyPreset('This Week', wkStart, now),
                ),
                _PresetTile(
                  label: 'This Month',
                  sub:   '${fmt.format(moStart)} – ${fmt.format(now)}',
                  onTap: () => _applyPreset('This Month', moStart, now),
                ),
                _PresetTile(
                  label: 'This Year',
                  sub:   '${fmt.format(yrStart)} – ${fmt.format(now)}',
                  onTap: () => _applyPreset('This Year', yrStart, now),
                ),
              ],
            ),

            const SizedBox(height: 14),

            GestureDetector(
              onTap: () => setState(() => _showCustom = !_showCustom),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _showCustom
                      ? AppColors.accentDim
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showCustom ? AppColors.accent : AppColors.border,
                    width: _showCustom ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text('Custom Range',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: _showCustom
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    )),
              ),
            ),

            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve:    Curves.easeOutCubic,
                child: _showCustom
                    ? Column(
                        children: [
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _DateCell(
                                  label:    'FROM',
                                  date:     _startDate,
                                  isActive: _editing == 'start',
                                  onTap: () =>
                                      setState(() => _editing = 'start'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateCell(
                                  label:    'TO',
                                  date:     _endDate,
                                  isActive: _editing == 'end',
                                  onTap: () =>
                                      setState(() => _editing = 'end'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _MiniCalendar(
                            selectedDate: _editing == 'start'
                                ? _startDate
                                : _endDate,
                            month:    _calMonth,
                            year:     _calYear,
                            onSelect: (d) {
                              setState(() {
                                if (_editing == 'start') {
                                  _startDate = d;
                                  _editing   = 'end';
                                } else {
                                  _endDate = d;
                                }
                              });
                            },
                            onPrevMonth: () => setState(() {
                              if (_calMonth == 1) {
                                _calMonth = 12;
                                _calYear--;
                              } else {
                                _calMonth--;
                              }
                            }),
                            onNextMonth: () => setState(() {
                              if (_calMonth == 12) {
                                _calMonth = 1;
                                _calYear++;
                              } else {
                                _calMonth++;
                              }
                            }),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _applyCustom,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color:        AppColors.accent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text('Apply',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.bg,
                                  )),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),

            const SizedBox(height: 14),

            if (widget.currentLabel != null)
              GestureDetector(
                onTap: () {
                  widget.onClear();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text('Clear Filter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Preset Tile ───────────────────────────────────────────────────────────────
class _PresetTile extends StatelessWidget {
  final String label, sub;
  final VoidCallback onTap;
  const _PresetTile(
      {required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:  MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            Text(sub,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}

// ── Date Cell ─────────────────────────────────────────────────────────────────
class _DateCell extends StatelessWidget {
  final String  label;
  final String? date;
  final bool    isActive;
  final VoidCallback onTap;
  const _DateCell({
    required this.label,
    required this.date,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentDim : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.accent : AppColors.textDim,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 3),
            Text(
              date != null
                  ? DateFormat('d MMM yyyy').format(DateTime.parse(date!))
                  : '—',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini Calendar ─────────────────────────────────────────────────────────────
class _MiniCalendar extends StatelessWidget {
  final String? selectedDate;
  final int month, year;
  final Function(String) onSelect;
  final VoidCallback onPrevMonth, onNextMonth;
  const _MiniCalendar({
    required this.selectedDate,
    required this.month,
    required this.year,
    required this.onSelect,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay     = DateTime(year, month, 1);
    final daysInMonth  = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final today        = DateTime.now();
    final selected     = selectedDate != null
        ? DateTime.parse(selectedDate!)
        : null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onPrevMonth,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.chevron_left_rounded,
                    size: 18, color: AppColors.textMuted),
              ),
            ),
            Text(
              DateFormat('MMMM yyyy').format(DateTime(year, month)),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: onNextMonth,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: AppColors.textDim,
                          )),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   7,
            childAspectRatio: 1,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (_, idx) {
            if (idx < startWeekday) return const SizedBox();
            final day      = idx - startWeekday + 1;
            final date     = DateTime(year, month, day);
            final isFuture = date.isAfter(today);
            final isSelected = selected != null &&
                date.year  == selected.year &&
                date.month == selected.month &&
                date.day   == selected.day;
            final isToday = date.year  == today.year &&
                date.month == today.month &&
                date.day   == today.day;

            return GestureDetector(
              onTap: isFuture
                  ? null
                  : () => onSelect(DateFormat('yyyy-MM-dd').format(date)),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : isToday
                          ? AppColors.accentDim
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isSelected
                      ? Border.all(color: AppColors.accentMuted)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text('$day',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isFuture
                          ? AppColors.textGhost
                          : isSelected
                              ? AppColors.bg
                              : AppColors.textSecondary,
                    )),
              ),
            );
          },
        ),
      ],
    );
  }
}
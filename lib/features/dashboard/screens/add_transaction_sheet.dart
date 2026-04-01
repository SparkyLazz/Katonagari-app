import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/database/app_database.dart';

// ── Format helper (display only — no currency symbol) ──
String _fmtAmount(String raw) {
  if (raw.isEmpty || raw == '0') return '0';
  final n = int.tryParse(raw) ?? 0;
  return n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
  );
}

// ─────────────────────────────────────────────────────────
//  AddTransactionSheet
// ─────────────────────────────────────────────────────────
class AddTransactionSheet extends ConsumerStatefulWidget {
  /// Pass an existing tx map to enter edit mode.
  /// Must contain: 'id', 'amount', 'cat', 'catId', 'note',
  /// 'oneTime', 'walletId', 'date'
  final Map<String, dynamic>? existingTx;

  const AddTransactionSheet({super.key, this.existingTx});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  String   _amount       = '';
  String?  _catId;
  String   _type         = 'expense';
  String   _mode         = 'quick';
  String   _note         = '';
  bool     _isOneTime    = false;
  String   _recurring    = 'none';
  bool     _showMore     = false;
  int?     _walletId;
  DateTime _selectedDate = DateTime.now();

  bool get _isEditMode => widget.existingTx != null;

  final _scrollController = ScrollController();
  final _noteFocusNode    = FocusNode();

  bool get _isIncome => _type == 'income';

  @override
  void initState() {
    super.initState();

    // ── Pre-fill state when editing ──────────────────────────────────────────
    final ex = widget.existingTx;
    if (ex != null) {
      final rawAmount = ex['amount'] as double;
      final absAmt    = rawAmount.abs();
      _amount       = absAmt.toInt().toString();
      _type         = rawAmount > 0 ? 'income' : 'expense';
      _note         = ex['note'] as String? ?? '';
      _isOneTime    = ex['oneTime'] as bool? ?? false;
      _walletId     = ex['walletId'] as int?;
      _selectedDate = DateTime.parse(ex['date'] as String);
      // Show the "more" panel if there is a note or it's one-time so user can see it
      if (_note.isNotEmpty || _isOneTime) _showMore = true;
    }

    _noteFocusNode.addListener(() {
      if (_noteFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve category after providers are available
    final ex = widget.existingTx;
    if (ex != null && _catId == null) {
      final catId = ex['catId'];
      if (catId != null) {
        setState(() => _catId = catId.toString());
      } else {
        // Fallback: match by name
        final catName = ex['cat'] as String?;
        if (catName != null) {
          final match = _cats.where((c) => c.name == catName).firstOrNull;
          if (match != null) setState(() => _catId = match.id.toString());
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  List<Category> get _cats {
    if (_isIncome) return ref.watch(incomeCategoriesProvider).valueOrNull ?? [];
    return ref.watch(expenseCategoriesProvider).valueOrNull ?? [];
  }

  Category? get _catObj {
    if (_catId == null) return null;
    try {
      return _cats.firstWhere((c) => c.id.toString() == _catId);
    } catch (_) {
      return null;
    }
  }

  bool get _hasAmount => _amount.isNotEmpty && _amount != '0';
  bool get _canSave   => _hasAmount && _catId != null;

  void _maybeAutoSelect(List<Wallet> wallets) {
    if (_walletId == null && wallets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _walletId = wallets.first.id);
      });
    }
  }

  void _onKey(String k) {
    setState(() {
      if (_amount.length >= 12) return;
      if (_amount.isEmpty && k == '000') return;
      if (_amount == '0' && k == '0') return;
      _amount = _amount.isEmpty ? k : _amount + k;
    });
  }

  void _onDelete() {
    setState(() {
      if (_amount.isNotEmpty)
        _amount = _amount.substring(0, _amount.length - 1);
    });
  }

  Future<void> _onSave() async {
    if (!_canSave) return;
    HapticFeedback.lightImpact();

    try {
      int? effectiveWalletId = _walletId;
      if (effectiveWalletId == null) {
        final wallet = await ref.read(walletRepoProvider).getDefault();
        effectiveWalletId = wallet?.id;
      }
      if (effectiveWalletId == null || _catObj == null) return;

      final txRepo  = ref.read(transactionRepoProvider);
      final newAmt  = double.parse(_amount);

      if (_isEditMode) {
        // ── UPDATE existing transaction ──────────────────────────────────────
        final ex       = widget.existingTx!;
        final txId     = ex['id'] as int;
        final oldAmt   = (ex['amount'] as double).abs();
        final wasIncome = (ex['amount'] as double) > 0;
        final oldWalletId = ex['walletId'] as int?;

        // Reverse old wallet delta
        if (oldWalletId != null) {
          final reversal = wasIncome ? -oldAmt : oldAmt;
          await ref.read(walletRepoProvider).adjustBalance(oldWalletId, reversal);
        }
        // Apply new wallet delta
        final newDelta = _isIncome ? newAmt : -newAmt;
        await ref.read(walletRepoProvider).adjustBalance(effectiveWalletId, newDelta);

        // Update the transaction row
        await txRepo.update(TransactionsCompanion(
          id:          drift.Value(txId),
          walletId:    drift.Value(effectiveWalletId),
          categoryId:  drift.Value(_catObj!.id),
          type:        drift.Value(_isIncome ? 'INCOME' : 'EXPENSE'),
          amount:      drift.Value(newAmt),
          note:        drift.Value(_note.isEmpty ? null : _note),
          date:        drift.Value(_selectedDate),
          isOneTime:   drift.Value(_isOneTime),
          isRecurring: drift.Value(_recurring != 'none'),
        ));
      } else {
        // ── INSERT new transaction ────────────────────────────────────────────
        await txRepo.add(TransactionsCompanion.insert(
          walletId:    effectiveWalletId,
          categoryId:  _catObj!.id,
          type:        _isIncome ? 'INCOME' : 'EXPENSE',
          amount:      newAmt,
          note:        drift.Value(_note.isEmpty ? null : _note),
          date:        _selectedDate,
          isOneTime:   drift.Value(_isOneTime),
          isRecurring: drift.Value(_recurring != 'none'),
        ));

        final delta = _isIncome ? newAmt : -newAmt;
        await ref.read(walletRepoProvider).adjustBalance(effectiveWalletId, delta);
      }

      if (mounted) {
        Navigator.of(context).pop({
          'type':      _type,
          'amount':    newAmt,
          'catId':     _catObj!.id,
          'catName':   _catObj!.name,
          'catIcon':   _catObj!.icon,
          'note':      _note,
          'isOneTime': _isOneTime,
          'recurring': _recurring,
        });
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  void _toggleType() {
    setState(() {
      _type  = _isIncome ? 'expense' : 'income';
      _catId = null;
    });
  }

  // ─────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletProvider).valueOrNull ?? [];
    final cur     = ref.currency;
    _maybeAutoSelect(wallets);

    final selectedWallet = wallets.where((w) => w.id == _walletId).firstOrNull;

    return Container(
      height: MediaQuery.of(context).size.height *
          (_mode == 'full' ? 0.94 : 0.78),
      decoration: BoxDecoration(
        color: AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildHeader(selectedWallet, wallets),
          Expanded(
            child: _mode == 'quick'
                ? _buildQuickMode(cur)
                : _buildFullMode(wallets, cur),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(Wallet? selectedWallet, List<Wallet> wallets) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_mode == 'full')
            GestureDetector(
              onTap: () => setState(() => _mode = 'quick'),
              child: Row(
                children: [
                  Icon(Icons.chevron_left_rounded,
                      color: AppColors.textSecondary, size: 20),
                  Text('Numpad',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            )
          else
            Row(
              children: [
                Text(
                  _isIncome ? '＋' : '－',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isIncome
                        ? AppColors.incomeGreen
                        : AppColors.expenseRed,
                  ),
                ),
                const SizedBox(width: 6),
                // Show "Edit Transaction" title when in edit mode
                Text(
                  _isEditMode ? 'Edit Transaction' : 'Add Transaction',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

          Row(
            children: [
              if (_isEditMode) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Editing',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Quick Mode
  // ─────────────────────────────────────────────────────
  Widget _buildQuickMode(CurrencyInfo cur) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _mode = 'full'),
            child: _buildAmountHero(cur),
          ),
        ),
        _buildCategoryRow(),
        const SizedBox(height: 6),
        Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildNumpad(),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: _SaveButton(
              canSave: _canSave,
              hasAmount: _hasAmount,
              onSave: _onSave,
              isEditMode: _isEditMode),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  //  Full Mode
  // ─────────────────────────────────────────────────────
  Widget _buildFullMode(List<Wallet> wallets, CurrencyInfo cur) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _buildAmountHeroSmall(cur)),
          const SizedBox(height: 4),

          Center(
            child: GestureDetector(
              onTap: _toggleType,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isIncome
                            ? AppColors.incomeGreen
                            : AppColors.expenseRed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_isIncome ? 'Income' : 'Expense'} · tap to switch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text('ACCOUNT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 1.2,
              )),
          const SizedBox(height: 10),
          _buildWalletPicker(wallets, cur),

          const SizedBox(height: 16),

          Text('CATEGORY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 1.2,
              )),
          const SizedBox(height: 10),
          _buildCategoryGrid(),

          const SizedBox(height: 4),

          GestureDetector(
            onTap: () => setState(() => _showMore = !_showMore),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showMore ? 'Less options' : 'Note, recurring & more',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _showMore ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showMore ? _buildMoreOptions() : const SizedBox.shrink(),
          ),

          GestureDetector(
            onTap: _onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _canSave ? AppColors.accent : AppColors.borderStrong,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canSave) ...[
                    Icon(Icons.check_rounded,
                        color: AppColors.bg, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _canSave
                        ? (_isEditMode ? 'Update Transaction' : 'Save Transaction')
                        : _hasAmount
                        ? 'Pick a category'
                        : 'Enter amount & category',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _canSave ? AppColors.bg : AppColors.textDim,
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

  // ── Wallet Picker ────────────────────────────────────────────────────────────
  Widget _buildWalletPicker(List<Wallet> wallets, CurrencyInfo cur) {
    if (wallets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.expenseRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.expenseRed.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.expenseRed, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No accounts found. Add one in Settings → Accounts.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.expenseRed),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: wallets.map((w) {
          final selected = w.id == _walletId;
          return GestureDetector(
            onTap: () => setState(() => _walletId = w.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentDim : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(w.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(w.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          )),
                      if (w.balance > 0)
                        Text(
                          cur.format(w.balance),
                          style: GoogleFonts.dmMono(
                            fontSize: 10,
                            color: selected
                                ? AppColors.accent.withOpacity(0.7)
                                : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.accent, size: 14),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── More Options ─────────────────────────────────────────────────────────────
  Widget _buildMoreOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: AppColors.textDim, letterSpacing: 1.2,
            )),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary:   AppColors.accent,
                    onPrimary: AppColors.bg,
                    surface:   AppColors.surfaceEl,
                    onSurface: AppColors.textPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_selectedDate.year  != DateTime.now().year  ||
                    _selectedDate.month != DateTime.now().month ||
                    _selectedDate.day   != DateTime.now().day)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Custom',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text('NOTE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: AppColors.textDim, letterSpacing: 1.2,
            )),
        const SizedBox(height: 8),
        TextField(
          focusNode:  _noteFocusNode,
          controller: TextEditingController(text: _note)
            ..selection = TextSelection.collapsed(offset: _note.length),
          onChanged:  (v) => _note = v,
          maxLength:  100,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'What was this for?',
            hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: AppColors.textDim),
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent, width: 1.5),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('One-time expense',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    Text('Excluded from recurring analysis',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isOneTime = !_isOneTime),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42, height: 24,
                  decoration: BoxDecoration(
                    color: _isOneTime
                        ? AppColors.accent
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: _isOneTime
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOneTime ? AppColors.bg : AppColors.textDim,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Amount Hero (quick mode) ─────────────────────────────────────────────────
  Widget _buildAmountHero(CurrencyInfo cur) {
    final display = _fmtAmount(_amount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleType,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _isIncome
                  ? AppColors.incomeGreen.withOpacity(0.12)
                  : AppColors.expenseRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isIncome ? '▲ Income' : '▼ Expense',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _isIncome
                    ? AppColors.incomeGreen
                    : AppColors.expenseRed,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(cur.symbol,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w500,
                  color: _amount.isEmpty
                      ? AppColors.textDim
                      : AppColors.textPrimary,
                )),
            const SizedBox(width: 4),
            Text(
              display.isEmpty ? '0' : display,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: display.length > 9
                    ? 32
                    : display.length > 6
                    ? 42
                    : 52,
                color: _amount.isEmpty
                    ? AppColors.textDim
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        AppColors.accentDim,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: AppColors.accentMuted),
          ),
          child: Text('Tap amount to see full form',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: AppColors.accent,
              )),
        ),
      ],
    );
  }

  // ── Amount Hero Small (full mode) ────────────────────────────────────────────
  Widget _buildAmountHeroSmall(CurrencyInfo cur) {
    final len      = _amount.length;
    final fontSize = len > 9 ? 28.0 : len > 6 ? 32.0 : 36.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(cur.symbol,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w500,
              color: _isIncome ? AppColors.incomeGreen : AppColors.expenseRed,
            )),
        const SizedBox(width: 4),
        Text(
          _fmtAmount(_amount).isEmpty ? '0' : _fmtAmount(_amount),
          style: GoogleFonts.dmSerifDisplay(
            fontSize: fontSize,
            color: _amount.isEmpty
                ? AppColors.textDim
                : _isIncome
                ? AppColors.incomeGreen
                : AppColors.expenseRed,
          ),
        ),
      ],
    );
  }

  // ── Category Row (quick mode) ────────────────────────────────────────────────
  Widget _buildCategoryRow() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _cats.map((c) {
          final selected = _catId == c.id.toString();
          return GestureDetector(
            onTap: () => setState(() => _catId = c.id.toString()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentDim : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(c.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(c.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Category Grid (full mode) ────────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount:   4,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing:  8,
      childAspectRatio: 1,
      children: _cats.map((c) {
        final selected = _catId == c.id.toString();
        return GestureDetector(
          onTap: () => setState(() => _catId = c.id.toString()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentDim : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 3),
                Text(c.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Numpad ───────────────────────────────────────────────────────────────────
  Widget _buildNumpad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', 'del'],
    ];
    return Column(
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: row.map((k) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _NumKey(
                label: k,
                onTap: () => k == 'del' ? _onDelete() : _onKey(k),
              ),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Numpad Key
// ─────────────────────────────────────────────────────────
class _NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 52,
        decoration: BoxDecoration(
          color: _pressed ? AppColors.borderStrong : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed ? AppColors.borderStrong : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: widget.label == 'del'
            ? Icon(Icons.backspace_outlined,
            color: AppColors.textSecondary, size: 20)
            : Text(
          widget.label,
          style: widget.label == '000'
              ? GoogleFonts.dmMono(
              fontSize: 15, color: AppColors.textPrimary)
              : GoogleFonts.dmSerifDisplay(
              fontSize: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Save Button
// ─────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  final bool canSave, hasAmount, isEditMode;
  final VoidCallback onSave;
  const _SaveButton({
    required this.canSave,
    required this.hasAmount,
    required this.onSave,
    required this.isEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canSave ? onSave : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: canSave ? AppColors.accent : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canSave ? AppColors.accent : AppColors.borderStrong,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSave) ...[
              Icon(Icons.check_rounded, color: AppColors.bg, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              canSave
                  ? (isEditMode ? 'Update' : 'Save')
                  : hasAmount
                  ? 'Pick a category'
                  : 'Enter amount',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: canSave ? AppColors.bg : AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
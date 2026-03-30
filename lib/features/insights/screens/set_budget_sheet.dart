import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';

class SetBudgetSheet extends ConsumerStatefulWidget {
  final Category category;
  final double?  existingAmount;
  const SetBudgetSheet({
    super.key,
    required this.category,
    this.existingAmount,
  });

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  String _amount = '';
  bool   _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingAmount != null) {
      _amount = widget.existingAmount!.toInt().toString();
    }
  }

  String get _display {
    if (_amount.isEmpty) return '0';
    final n = int.tryParse(_amount) ?? 0;
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  void _onKey(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '⌫') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (key == '000') {
        if (_amount.isNotEmpty) _amount += '000';
      } else {
        if (_amount == '0') {
          _amount = key;
        } else if (_amount.length < 12) {
          _amount += key;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_amount.isEmpty || _amount == '0') return;
    setState(() => _saving = true);

    final now  = DateTime.now();
    final repo = ref.read(budgetRepoProvider);
    await repo.upsert(
      categoryId: widget.category.id,
      amount:     double.parse(_amount),
      month:      now.month,
      year:       now.year,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = _amount.isNotEmpty && _amount != '0';
    final cur       = ref.currency; // ← live currency symbol

    return Container(
      decoration: const BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(11),
                    border:       Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(widget.category.icon,
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingAmount != null
                            ? 'Edit Budget'
                            : 'Set Budget',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 18, color: AppColors.textPrimary),
                      ),
                      Text(widget.category.name,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color:        AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ← was hardcoded 'Rp'
                Text(cur.symbol,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w500,
                      color: AppColors.textDim,
                    )),
                const SizedBox(width: 8),
                Text(
                  _display,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 40,
                    color: hasAmount
                        ? AppColors.textPrimary
                        : AppColors.textDim,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Numpad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ...['789', '456', '123', '000', '0⌫'].map((row) {
                  if (row == '000') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NumKey(
                                label: '000', onTap: () => _onKey('000')),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(child: SizedBox()),
                          const SizedBox(width: 6),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    );
                  }

                  if (row == '0⌫') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _NumKey(
                                label: '0', onTap: () => _onKey('0')),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _NumKey(
                                label: '⌫',
                                isDelete: true,
                                onTap: () => _onKey('⌫')),
                          ),
                        ],
                      ),
                    );
                  }

                  final keys = row.split('');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: keys.asMap().entries.map((e) {
                        final k = e.value;
                        return Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(left: e.key > 0 ? 6 : 0),
                            child: _NumKey(
                                label: k, onTap: () => _onKey(k)),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),

                const SizedBox(height: 4),

                // Save button
                GestureDetector(
                  onTap: hasAmount && !_saving ? _save : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width:  double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: hasAmount
                          ? AppColors.accent
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasAmount
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bg,
                            ),
                          )
                        : Text(
                            hasAmount ? 'Save Budget' : 'Enter an amount',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   15,
                              fontWeight: FontWeight.w700,
                              color: hasAmount
                                  ? AppColors.bg
                                  : AppColors.textDim,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String    label;
  final VoidCallback onTap;
  final bool      isDelete;
  const _NumKey({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDelete ? AppColors.expenseRedDim : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDelete
                ? AppColors.expenseRed.withOpacity(0.2)
                : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: isDelete
              ? const TextStyle(fontSize: 18, color: AppColors.expenseRed)
              : GoogleFonts.dmSerifDisplay(
                  fontSize: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
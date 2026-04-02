// lib/features/reports/screens/report_sheet.dart
//
// Bottom sheet that lets the user choose:
//   • Report type  → Monthly | Yearly
//   • Period       → month/year picker
// then taps "Generate PDF" which builds & shares the report.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../data/database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point: call this from Settings
// ─────────────────────────────────────────────────────────────────────────────
void showReportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ReportSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet();

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  // ── State ─────────────────────────────────────────────────────────────────
  bool    _isMonthly = true;
  int     _year      = DateTime.now().year;
  int     _month     = DateTime.now().month;
  bool    _loading   = false;
  String? _error;

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  // ── Generate ──────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });

    try {
      final repo = ref.read(transactionRepoProvider);
      final cur  = ref.read(currencyProvider);

      List<TransactionWithCategory> txList;
      double totalIncome  = 0;
      double totalExpense = 0;
      String periodLabel;

      if (_isMonthly) {
        txList      = await repo.watchWithCategoryByMonth(_month, _year).first;
        periodLabel = '${_months[_month - 1]} $_year';
      } else {
        // Full year: fetch all months and concatenate
        txList = [];
        for (int m = 1; m <= 12; m++) {
          final monthTx = await repo.watchWithCategoryByMonth(m, _year).first;
          txList.addAll(monthTx);
        }
        periodLabel = 'Year $_year';
      }

      for (final t in txList) {
        if (t.transaction.type == 'INCOME') {
          totalIncome += t.transaction.amount;
        } else {
          totalExpense += t.transaction.amount;
        }
      }

      final data = ReportData(
        periodLabel:  periodLabel,
        totalIncome:  totalIncome,
        totalExpense: totalExpense,
        currency:     cur,
        transactions: txList,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close sheet before share sheet opens
      await PdfReportService.generate(data);
    } catch (e) {
      setState(() { _error = 'Something went wrong. Please try again.'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceEl,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentMuted),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📄', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export Report',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 20, color: AppColors.textPrimary)),
                    Text('Generate a PDF you can save or share',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.textDim)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Report type toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTypeToggle(),
          ),
          const SizedBox(height: 20),

          // Period picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isMonthly ? _buildMonthPicker() : _buildYearPicker(),
          ),
          const SizedBox(height: 8),

          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(_error!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.expenseRed)),
            ),

          const SizedBox(height: 16),

          // Generate button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _buildGenerateButton(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Type Toggle ────────────────────────────────────────────────────────────
  Widget _buildTypeToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _toggleOption('Monthly', _isMonthly,
                  () => setState(() => _isMonthly = true)),
          _toggleOption('Yearly', !_isMonthly,
                  () => setState(() => _isMonthly = false)),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:        active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.bg : AppColors.textDim,
              )),
        ),
      ),
    );
  }

  // ── Month Picker ───────────────────────────────────────────────────────────
  Widget _buildMonthPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT PERIOD',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textDim,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),

        // Year row
        _periodRow(
          label: 'Year',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _arrowBtn(Icons.chevron_left_rounded,
                      () => setState(() => _year--)),
              const SizedBox(width: 8),
              Text('$_year',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              _arrowBtn(Icons.chevron_right_rounded,
                  _year < DateTime.now().year
                      ? () => setState(() => _year++)
                      : null),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Month grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: List.generate(12, (i) {
            final m       = i + 1;
            final active  = m == _month;
            final isFuture = _year == DateTime.now().year &&
                m > DateTime.now().month;
            return GestureDetector(
              onTap: isFuture ? null : () => setState(() => _month = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color:  active ? AppColors.accentDim
                      : isFuture ? Colors.transparent
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? AppColors.accent
                        : isFuture ? AppColors.border.withOpacity(0.3)
                        : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _months[i].substring(0, 3),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.accent
                        : isFuture ? AppColors.textGhost
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Year Picker ────────────────────────────────────────────────────────────
  Widget _buildYearPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT YEAR',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textDim,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        _periodRow(
          label: 'Year',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _arrowBtn(Icons.chevron_left_rounded,
                      () => setState(() => _year--)),
              const SizedBox(width: 12),
              Text('$_year',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 12),
              _arrowBtn(Icons.chevron_right_rounded,
                  _year < DateTime.now().year
                      ? () => setState(() => _year++)
                      : null),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _periodRow({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textMuted)),
          child,
        ],
      ),
    );
  }

  Widget _arrowBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceEl,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 16,
            color: onTap == null
                ? AppColors.textGhost
                : AppColors.textSecondary),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _loading ? null : _generate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color:        _loading ? AppColors.accentMuted : AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: _loading
            ? SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.bg),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.bg, size: 18),
            const SizedBox(width: 8),
            Text('Generate PDF',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bg,
                )),
          ],
        ),
      ),
    );
  }
}
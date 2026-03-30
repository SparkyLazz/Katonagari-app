import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';

/// Shows a bottom sheet month/year picker.
/// Updates [selectedMonthProvider] on selection.
Future<void> showMonthPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _MonthPickerSheet(),
  );
}

class _MonthPickerSheet extends ConsumerStatefulWidget {
  const _MonthPickerSheet();

  @override
  ConsumerState<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends ConsumerState<_MonthPickerSheet> {
  late int _year;
  final int _minYear = 2020;
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Start on the currently selected year
    _year = ref.read(selectedMonthProvider).year;
  }

  bool _isFuture(int month) =>
      _year > _now.year || (_year == _now.year && month > _now.month);

  bool _isSelected(int month) {
    final sel = ref.read(selectedMonthProvider);
    return sel.year == _year && sel.month == month;
  }

  void _select(int month) {
    if (_isFuture(month)) return;
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(_year, month);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selected  = ref.watch(selectedMonthProvider);
    final canGoNext  = _year < _now.year;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return Container(
      decoration: const BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
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
          const SizedBox(height: 20),

          // Year navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Prev year
              GestureDetector(
                onTap: _year > _minYear
                    ? () => setState(() => _year--)
                    : null,
                child: AnimatedOpacity(
                  opacity:  _year > _minYear ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ),

              // Year label
              GestureDetector(
                onTap: () => setState(() => _year = _now.year),
                child: Column(
                  children: [
                    Text('$_year',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 22, color: AppColors.textPrimary)),
                    if (_year != _now.year)
                      Text('tap to go back to ${_now.year}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: AppColors.accent)),
                  ],
                ),
              ),

              // Next year
              GestureDetector(
                onTap: canGoNext ? () => setState(() => _year++) : null,
                child: AnimatedOpacity(
                  opacity:  canGoNext ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Month grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap:     true,
            physics:        const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing:  10,
            childAspectRatio: 1.6,
            children: List.generate(12, (i) {
              final month    = i + 1;
              final isFuture = _isFuture(month);
              final isSel    = _isSelected(month);
              final isCurrentMonth = _year == _now.year && month == _now.month;

              return GestureDetector(
                onTap: () => _select(month),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.accent
                        : isCurrentMonth
                            ? AppColors.accentDim
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? AppColors.accent
                          : isCurrentMonth
                              ? AppColors.accent
                              : AppColors.border,
                      width: isSel || isCurrentMonth ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    months[i],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   13,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isFuture
                          ? AppColors.textGhost
                          : isSel
                              ? AppColors.bg
                              : isCurrentMonth
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // "This month" shortcut — only show if not already there
          if (selected.year != _now.year || selected.month != _now.month)
            GestureDetector(
              onTap: () {
                ref.read(selectedMonthProvider.notifier).state =
                    DateTime(_now.year, _now.month);
                Navigator.of(context).pop();
              },
              child: Container(
                width:  double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Back to ${DateFormat('MMMM yyyy').format(_now)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
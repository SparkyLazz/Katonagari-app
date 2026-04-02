import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';

// ── Add Goal Sheet ────────────────────────────────────────────────────────────
class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key});

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _nameController = TextEditingController();
  String    _amount     = '';
  String    _icon       = '🎯';
  DateTime? _targetDate;
  bool      _saving     = false;

  static const _icons = [
    '🎯','🏠','🚗','✈️','💍','📱','💻','🎓','🏋️','🛍️',
    '🏖️','🎮','🎸','📷','⌚','💎','🏦','🌱','🐾','🎁',
  ];

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
        if (_amount.length < 12) _amount += key;
      }
    });
  }

  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context:     context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 1),
      firstDate:   now,
      lastDate:    DateTime(now.year + 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   AppColors.accent,
            surface:   AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _targetDate = date);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _amount.isEmpty || _amount == '0') return;
    setState(() => _saving = true);

    await ref.read(goalRepoProvider).add(GoalsCompanion.insert(
      name:         name,
      icon:         drift.Value(_icon),
      targetAmount: double.parse(_amount),
      savedAmount:  const drift.Value(0),
      targetDate:   drift.Value(_targetDate),
    ));

    if (mounted) Navigator.pop(context);
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
          _amount.isNotEmpty &&
          _amount != '0';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = ref.currency;

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                  Text('New Goal',
                      style: GoogleFonts.dmSerifDisplay(
                          fontSize: 20, color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.textDim, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Icon picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Icon',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _icons.map((ic) {
                      final selected = _icon == ic;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _icon = ic);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accentDim
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(ic,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Goal name',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  TextField(
                    controller:  _nameController,
                    onChanged:   (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:    'e.g. Emergency fund, New phone…',
                      hintStyle:   GoogleFonts.plusJakartaSans(
                          color: AppColors.textDim, fontSize: 13),
                      filled:      true,
                      fillColor:   AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border:      OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Target date (optional)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Text(
                        _targetDate != null
                            ? 'By ${DateFormat('dd MMM yyyy').format(_targetDate!)}'
                            : 'Target date (optional)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _targetDate != null
                              ? AppColors.textPrimary
                              : AppColors.textDim,
                        ),
                      ),
                      const Spacer(),
                      if (_targetDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _targetDate = null),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: AppColors.textDim),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Amount display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target amount',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(cur.symbol,
                          style: GoogleFonts.dmMono(
                              fontSize: 20, color: AppColors.textMuted)),
                      const SizedBox(width: 6),
                      Text(_display,
                          style: GoogleFonts.dmMono(
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              color: _amount.isEmpty
                                  ? AppColors.textDim
                                  : AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildNumpad(),
            ),
            const SizedBox(height: 16),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: GestureDetector(
                onTap: _canSave && !_saving ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    color: _canSave
                        ? AppColors.accent
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _canSave
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Text('Save Goal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _canSave
                            ? Colors.white
                            : AppColors.textDim,
                      )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const keys = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['000','0','⌫'],
    ];
    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: row.map((k) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => _onKey(k),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: k == '⌫'
                      ? Icon(Icons.backspace_outlined,
                      size: 18, color: AppColors.textSecondary)
                      : Text(k,
                      style: GoogleFonts.dmMono(
                          fontSize: 18,
                          color: AppColors.textPrimary)),
                ),
              ),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }
}

// ── Top-up Goal Sheet ─────────────────────────────────────────────────────────
class TopUpGoalSheet extends ConsumerStatefulWidget {
  final Goal goal;
  const TopUpGoalSheet({super.key, required this.goal});

  @override
  ConsumerState<TopUpGoalSheet> createState() => _TopUpGoalSheetState();
}

class _TopUpGoalSheetState extends ConsumerState<TopUpGoalSheet> {
  String _amount = '';
  bool   _saving = false;

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
        if (_amount.length < 12) _amount += key;
      }
    });
  }

  Future<void> _save() async {
    if (_amount.isEmpty || _amount == '0') return;
    setState(() => _saving = true);
    await ref.read(goalRepoProvider).topUp(
      widget.goal,
      double.parse(_amount),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cur      = ref.currency;
    final goal     = widget.goal;
    final remaining = (goal.targetAmount - goal.savedAmount)
        .clamp(0.0, double.infinity);
    final canSave  = _amount.isNotEmpty && _amount != '0';

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Text(goal.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 18,
                              color: AppColors.textPrimary)),
                      Text(
                        '${cur.format(goal.savedAmount)} / ${cur.format(goal.targetAmount)}',
                        style: GoogleFonts.dmMono(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textDim, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Remaining hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    '${cur.format(remaining)} still needed to reach goal',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(cur.symbol,
                    style: GoogleFonts.dmMono(
                        fontSize: 20, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                Text(_display,
                    style: GoogleFonts.dmMono(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: _amount.isEmpty
                            ? AppColors.textDim
                            : AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Numpad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildNumpad(),
          ),
          const SizedBox(height: 16),

          // Add button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: GestureDetector(
              onTap: canSave && !_saving ? _save : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: canSave ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: canSave ? AppColors.accent : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: _saving
                    ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text('Add to Goal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: canSave
                          ? Colors.white
                          : AppColors.textDim,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    const keys = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['000','0','⌫'],
    ];
    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: row.map((k) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => _onKey(k),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: k == '⌫'
                      ? Icon(Icons.backspace_outlined,
                      size: 18,
                      color: AppColors.textSecondary)
                      : Text(k,
                      style: GoogleFonts.dmMono(
                          fontSize: 18,
                          color: AppColors.textPrimary)),
                ),
              ),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/database/app_database.dart';

class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key});

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  String _type       = 'OWE'; // 'OWE' | 'OWED'
  String _amount     = '';
  String _personName = '';
  DateTime? _dueDate;
  String _note       = '';
  bool   _saving     = false;

  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  // ── Numpad ────────────────────────────────────────────
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
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
      } else if (key == '000') {
        if (_amount.isNotEmpty) _amount += '000';
      } else {
        if (_amount.length < 12) _amount += key;
      }
    });
  }

  // ── Date picker ───────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   AppColors.accent,
            surface:   AppColors.surfaceEl,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Save ──────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (_amount.isEmpty || name.isEmpty) return;
    setState(() => _saving = true);

    await ref.read(debtRepoProvider).add(
      DebtsCompanion.insert(
        type:       _type,
        personName: name,
        amount:     double.parse(_amount),
        dueDate:    Value(_dueDate),
        note:       Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  bool get _canSave =>
      _amount.isNotEmpty && _nameCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardUp = bottomInset > 100;

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
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
                  Text('New Debt / Loan',
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

            // ── Type toggle: Hutang / Piutang ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _TypeBtn(
                      label:    'Debt',
                      sublabel: 'I owe',
                      icon:     '💸',
                      active:   _type == 'OWE',
                      color:    AppColors.expenseRed,
                      dimColor: AppColors.expenseRedDim,
                      onTap:    () { HapticFeedback.selectionClick(); setState(() => _type = 'OWE'); },
                    ),
                    _TypeBtn(
                      label:    'Claim',
                      sublabel: 'Owed to me',
                      icon:     '🤝',
                      active:   _type == 'OWED',
                      color:    AppColors.incomeGreen,
                      dimColor: AppColors.incomeGreenDim,
                      onTap:    () { HapticFeedback.selectionClick(); setState(() => _type = 'OWED'); },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Person name ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_type == 'OWE' ? 'Owed to' : 'Owed by',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color:        AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller:  _nameCtrl,
                      focusNode:   _nameFocus,
                      onChanged:   (_) => setState(() {}),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText:        'Person or group name...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: AppColors.textDim),
                        border:          InputBorder.none,
                        contentPadding:  const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            size: 18, color: AppColors.textDim),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Due date + Note row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Due date chip
                  GestureDetector(
                    onTap: _pickDate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color:  _dueDate != null
                            ? AppColors.accentDim
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _dueDate != null
                              ? AppColors.accentMuted
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 14,
                              color: _dueDate != null
                                  ? AppColors.accent
                                  : AppColors.textDim),
                          const SizedBox(width: 6),
                          Text(
                            _dueDate != null
                                ? DateFormat('d MMM yyyy').format(_dueDate!)
                                : 'Due date',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _dueDate != null
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _dueDate != null
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                          if (_dueDate != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _dueDate = null),
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
            const SizedBox(height: 12),

            // ── Note ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller:  _noteCtrl,
                  focusNode:   _noteFocus,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Note (optional)...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: AppColors.textDim),
                    border:         InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    prefixIcon: Icon(Icons.notes_rounded,
                        size: 18, color: AppColors.textDim),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount display ──
            if (!isKeyboardUp) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Rp ',
                        style: GoogleFonts.dmMono(
                            fontSize: 16, color: AppColors.textMuted)),
                    Text(
                      _display,
                      style: GoogleFonts.dmMono(
                        fontSize: 36,
                        fontWeight: FontWeight.w500,
                        color: _amount.isEmpty
                            ? AppColors.textGhost
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Numpad ──
              _Numpad(onKey: _onKey),
              const SizedBox(height: 16),

              // ── Save button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: AnimatedOpacity(
                    opacity:  _canSave ? 1 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _canSave && !_saving ? _save : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _type == 'OWE'
                              ? AppColors.expenseRed
                              : AppColors.incomeGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: _saving
                            ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                            : Text(
                          _type == 'OWE'
                              ? 'Save Debt'
                              : 'Save Claim',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Compact save when keyboard is up
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: AnimatedOpacity(
                    opacity: _canSave ? 1 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _canSave && !_saving ? _save : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _type == 'OWE'
                              ? AppColors.expenseRed
                              : AppColors.incomeGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _type == 'OWE' ? 'Save Debt' : 'Save Claim',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Type button ───────────────────────────────────────────────────────────────
class _TypeBtn extends StatelessWidget {
  final String label, sublabel, icon;
  final bool   active;
  final Color  color, dimColor;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.active,
    required this.color,
    required this.dimColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:        active ? dimColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? color : AppColors.textMuted,
                  )),
              Text(sublabel,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: AppColors.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────
class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  const _Numpad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', '⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: keys.map((row) => Row(
          children: row.map((k) => Expanded(
            child: GestureDetector(
              onTap: () => onKey(k),
              child: Container(
                height: 52,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
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
          )).toList(),
        )).toList(),
      ),
    );
  }
}
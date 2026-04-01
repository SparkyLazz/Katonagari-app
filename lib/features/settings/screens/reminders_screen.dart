import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/notification_service.dart';

// ─────────────────────────────────────────────────────────
//  RemindersScreen  — converted to ConsumerStatefulWidget
// ─────────────────────────────────────────────────────────
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _loading = true;

  bool      _dailyEnabled  = false;
  TimeOfDay _dailyTime     = const TimeOfDay(hour: 21, minute: 0);

  bool      _weeklyEnabled = false;
  int       _weeklyDay     = 1;
  TimeOfDay _weeklyTime    = const TimeOfDay(hour: 9, minute: 0);

  List<BillReminder> _bills = [];

  final _svc = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _svc.loadSettings();
    final bills    = await _svc.getBills();
    if (!mounted) return;
    setState(() {
      _dailyEnabled  = settings['dailyEnabled']  as bool;
      _dailyTime     = TimeOfDay(
          hour:   settings['dailyHour'] as int,
          minute: settings['dailyMin']  as int);
      _weeklyEnabled = settings['weeklyEnabled'] as bool;
      _weeklyDay     = settings['weeklyDay']     as int;
      _weeklyTime    = TimeOfDay(
          hour:   settings['weeklyHour'] as int,
          minute: settings['weeklyMin']  as int);
      _bills   = bills;
      _loading = false;
    });
  }

  // ── Helpers ───────────────────────────────────────────
  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _weekdayLabel(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:  return '${n}st';
      case 2:  return '${n}nd';
      case 3:  return '${n}rd';
      default: return '${n}th';
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) =>
      showTimePicker(
        context: context,
        initialTime: initial,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary:          AppColors.accent,
              onPrimary:        AppColors.bg,
              secondary:        AppColors.accent,
              onSecondary:      AppColors.bg,
              tertiary:         AppColors.accent,
              onTertiary:       AppColors.bg,
              surface:          AppColors.surfaceEl,
              onSurface:        AppColors.textPrimary,
              surfaceContainer: AppColors.surface,
            ),
          ),
          child: child!,
        ),
      );

  // ── Daily ─────────────────────────────────────────────
  Future<void> _toggleDaily(bool val) async {
    if (val) {
      final ok = await _svc.requestPermissions();
      if (!ok || !mounted) return;
      try {
        await _svc.scheduleDailyReminder(_dailyTime);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not schedule reminder. Please try again.'),
          ));
        }
        return;
      }
    } else {
      await _svc.cancelDailyReminder();
    }
    if (mounted) setState(() => _dailyEnabled = val);
    HapticFeedback.lightImpact();
  }

  Future<void> _changeDailyTime() async {
    final t = await _pickTime(_dailyTime);
    if (t == null) return;
    setState(() => _dailyTime = t);
    if (_dailyEnabled) await _svc.scheduleDailyReminder(t);
  }

  // ── Weekly ────────────────────────────────────────────
  Future<void> _toggleWeekly(bool val) async {
    if (val) {
      final ok = await _svc.requestPermissions();
      if (!ok || !mounted) return;
      try {
        await _svc.scheduleWeeklySummary(_weeklyDay, _weeklyTime);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not schedule reminder. Please try again.'),
          ));
        }
        return;
      }
    } else {
      await _svc.cancelWeeklySummary();
    }
    if (mounted) setState(() => _weeklyEnabled = val);
    HapticFeedback.lightImpact();
  }

  Future<void> _changeWeeklyTime() async {
    final t = await _pickTime(_weeklyTime);
    if (t == null) return;
    setState(() => _weeklyTime = t);
    if (_weeklyEnabled) await _svc.scheduleWeeklySummary(_weeklyDay, t);
  }

  Future<void> _changeWeeklyDay(int day) async {
    setState(() => _weeklyDay = day);
    if (_weeklyEnabled) await _svc.scheduleWeeklySummary(day, _weeklyTime);
  }

  // ── Bills ─────────────────────────────────────────────
  Future<void> _deleteBill(String id) async {
    await _svc.deleteBill(id);
    setState(() => _bills.removeWhere((b) => b.id == id));
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleBill(BillReminder bill, bool val) async {
    final updated = bill.copyWith(isActive: val);
    await _svc.updateBill(updated);
    setState(() {
      final i = _bills.indexWhere((b) => b.id == bill.id);
      if (i != -1) _bills[i] = updated;
    });
  }

  void _openAddBill({BillReminder? existing}) {
    final cur = ref.read(currencyProvider); // ← pass cur to sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BillSheet(
        existing: existing,
        cur:      cur,
        onSave: (bill) async {
          if (existing == null) {
            await _svc.addBill(bill);
            setState(() => _bills.add(bill));
          } else {
            await _svc.updateBill(bill);
            setState(() {
              final i = _bills.indexWhere((b) => b.id == bill.id);
              if (i != -1) _bills[i] = bill;
            });
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cur = ref.currency; // ← read once

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                  Expanded(
                    child: Text('Reminders',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 22, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),

            if (_loading)
              Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _buildSectionLabel('DAILY REMINDER'),
                    const SizedBox(height: 8),
                    _buildDailySection(),

                    const SizedBox(height: 24),
                    _buildSectionLabel('WEEKLY SUMMARY'),
                    const SizedBox(height: 8),
                    _buildWeeklySection(),

                    const SizedBox(height: 24),
                    _buildSectionLabel('BILL REMINDERS'),
                    const SizedBox(height: 8),
                    _buildBillsSection(cur),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textDim, letterSpacing: 1.2,
        ),
      );

  // ─────────────────────────────────────────────────────
  //  Daily Section  (unchanged from original)
  // ─────────────────────────────────────────────────────
  Widget _buildDailySection() {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Text('📝', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Log reminder',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      Text(
                        _dailyEnabled
                            ? 'Every day at ${_fmt(_dailyTime)}'
                            : 'Reminds you to log transactions daily',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _Toggle(value: _dailyEnabled, onChanged: _toggleDaily),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve:    Curves.easeInOut,
            child: _dailyEnabled
                ? Column(
                    children: [
                      Divider(height: 1, color: AppColors.border),
                      GestureDetector(
                        onTap: _changeDailyTime,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Reminder time',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  )),
                              Row(
                                children: [
                                  Text(_fmt(_dailyTime),
                                      style: GoogleFonts.dmMono(
                                        fontSize: 13, fontWeight: FontWeight.w500,
                                        color: AppColors.accent,
                                      )),
                                  const SizedBox(width: 6),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 16, color: AppColors.textDim),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Weekly Section  (unchanged from original)
  // ─────────────────────────────────────────────────────
  Widget _buildWeeklySection() {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly summary',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      Text(
                        _weeklyEnabled
                            ? 'Every ${_weekdayLabel(_weeklyDay)} at ${_fmt(_weeklyTime)}'
                            : 'A snapshot of your weekly spending',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _Toggle(value: _weeklyEnabled, onChanged: _toggleWeekly),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve:    Curves.easeInOut,
            child: _weeklyEnabled
                ? Column(
                    children: [
                      Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Day',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: AppColors.textMuted,
                                )),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(7, (i) {
                                final day = i + 1;
                                final sel = _weeklyDay == day;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => _changeWeeklyDay(day),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.accent
                                            : AppColors.surfaceEl,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: sel
                                              ? AppColors.accent
                                              : AppColors.border,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _weekdayLabel(day)[0],
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? AppColors.bg
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _changeWeeklyTime,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Time',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: AppColors.textMuted,
                                  )),
                              Row(
                                children: [
                                  Text(_fmt(_weeklyTime),
                                      style: GoogleFonts.dmMono(
                                        fontSize: 13, fontWeight: FontWeight.w500,
                                        color: AppColors.accent,
                                      )),
                                  const SizedBox(width: 6),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 16, color: AppColors.textDim),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Bills Section
  // ─────────────────────────────────────────────────────
  Widget _buildBillsSection(CurrencyInfo cur) {
    return Column(
      children: [
        if (_bills.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text('🧾', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No bills yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      Text("Add bills to get reminders before they're due.",
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ..._bills.map((bill) => _buildBillTile(bill, cur)),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: () => _openAddBill(),
          child: Container(
            width: double.infinity, height: 48,
            decoration: BoxDecoration(
              color:        AppColors.accentDim,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: AppColors.accentMuted),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text('Add Bill',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillTile(BillReminder bill, CurrencyInfo cur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        AppColors.surfaceEl,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(bill.icon,
                  style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: bill.isActive
                            ? AppColors.textPrimary
                            : AppColors.textDim,
                      )),
                  Text(
                    'Due ${_ordinal(bill.dueDay)} · notify ${bill.daysBefore}d before',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // ← was hardcoded 'Rp ${bill.amount...}'
            Text(
              cur.format(bill.amount),
              style: GoogleFonts.dmMono(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),

            _Toggle(
              value:     bill.isActive,
              onChanged: (v) => _toggleBill(bill, v),
              small:     true,
            ),
            const SizedBox(width: 4),

            GestureDetector(
              onTap: () => _openAddBill(existing: bill),
              child: Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.textMuted),
            ),
            const SizedBox(width: 4),

            GestureDetector(
              onTap: () => _showDeleteConfirm(bill),
              child: Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.expenseRed),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BillReminder bill) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceEl,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Remove reminder?',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 18, color: AppColors.textPrimary)),
        content: Text(
          'Stop reminding you about "${bill.name}".',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBill(bill.id);
            },
            child: Text('Remove',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.expenseRed,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Reusable Toggle  (unchanged)
// ─────────────────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final bool  value;
  final void Function(bool) onChanged;
  final bool  small;
  const _Toggle({
    required this.value,
    required this.onChanged,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = small ? 36.0 : 44.0;
    final h = small ? 20.0 : 24.0;
    final d = small ? 14.0 : 18.0;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: w, height: h,
        decoration: BoxDecoration(
          color:        value ? AppColors.accent : AppColors.borderStrong,
          borderRadius: BorderRadius.circular(h / 2),
        ),
        child: AnimatedAlign(
          duration:  const Duration(milliseconds: 200),
          curve:     Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: d, height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.bg : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Bill Add/Edit Sheet
// ─────────────────────────────────────────────────────────
class _BillSheet extends StatefulWidget {
  final BillReminder?             existing;
  final CurrencyInfo              cur;      // ← receives live currency
  final void Function(BillReminder) onSave;
  const _BillSheet({
    this.existing,
    required this.cur,
    required this.onSave,
  });

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _icon      = '🧾';
  int    _dueDay    = 1;
  int    _daysBefore = 3;
  bool   _saving    = false;

  final _icons = [
    '🧾','📱','💡','🌊','🏠','🚗','🎵','🎮','☕','🏥',
    '📺','🌐','🛡️','💼','✈️','🎓','🐾','🏋️','🎨','📦',
  ];

  final _presets = [
    ('Netflix',  '🎵'), ('Spotify',  '🎵'), ('Disney+', '📺'),
    ('Internet', '🌐'), ('Electric', '💡'), ('Water',   '🌊'),
    ('Rent',     '🏠'), ('Phone',    '📱'), ('GoPay',   '📱'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e        = widget.existing!;
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amount.toInt().toString();
      _icon          = e.icon;
      _dueDay        = e.dueDay;
      _daysBefore    = e.daysBefore;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _amountCtrl.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final bill = BillReminder(
      id:         widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name:       _nameCtrl.text.trim(),
      icon:       _icon,
      amount:     double.tryParse(_amountCtrl.text) ?? 0,
      dueDay:     _dueDay,
      daysBefore: _daysBefore,
    );
    widget.onSave(bill);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.cur; // ← from parent

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surfaceEl,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color:        AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                widget.existing == null ? 'Add Bill' : 'Edit Bill',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // Presets
              _label('QUICK PICK'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _presets.map((p) {
                  final sel = _nameCtrl.text == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _nameCtrl.text = p.$1;
                      _icon          = p.$2;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.accentDim
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.$2, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(p.$1,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('NAME'),
                        const SizedBox(height: 6),
                        _textField(_nameCtrl, 'e.g. Netflix'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ← was hardcoded 'AMOUNT (RP)'
                        _label('AMOUNT (${cur.symbol})'),
                        const SizedBox(height: 6),
                        _textField(_amountCtrl, '0', numeric: true),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _label('ICON'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _icons.map((ic) {
                  final sel = ic == _icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = ic),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.accentDim
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.accent : AppColors.border,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(ic,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              _label('DUE DAY OF MONTH'),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount:       28,
                  itemBuilder:     (_, i) {
                    final day = i + 1;
                    final sel = _dueDay == day;
                    return GestureDetector(
                      onTap: () => setState(() => _dueDay = day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        width: 36, height: 36,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.accent
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? AppColors.accent : AppColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text('$day',
                            style: GoogleFonts.dmMono(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: sel
                                  ? AppColors.bg
                                  : AppColors.textSecondary,
                            )),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              _label('NOTIFY ME'),
              const SizedBox(height: 8),
              Row(
                children: [1, 3, 7].map((d) {
                  final sel = _daysBefore == d;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _daysBefore = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        margin: const EdgeInsets.only(right: 8),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.accentDim
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? AppColors.accent : AppColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$d day${d == 1 ? '' : 's'} before',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: sel
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: _canSave ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    color: _canSave
                        ? AppColors.accent
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.existing == null
                        ? 'Add Reminder'
                        : 'Save Changes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _canSave ? AppColors.bg : AppColors.textDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textDim, letterSpacing: 1.2,
        ),
      );

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    bool numeric = false,
  }) =>
      TextField(
        controller:   ctrl,
        onChanged:    (_) => setState(() {}),
        keyboardType: numeric
            ? TextInputType.number
            : TextInputType.text,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: AppColors.textDim),
          filled:    true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide(
                color: AppColors.accent, width: 1.5),
          ),
        ),
      );
}
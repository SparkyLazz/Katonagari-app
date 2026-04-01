import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/database/app_database.dart';
import 'reminders_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'accounts_screen.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  int _phase = 0;
  bool _showCats = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150),
            () { if (mounted) setState(() => _phase = 1); });
    Future.delayed(const Duration(milliseconds: 300),
            () { if (mounted) setState(() => _phase = 2); });
    Future.delayed(const Duration(milliseconds: 500),
            () { if (mounted) setState(() => _phase = 3); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ── Read live preference state ──
    final lang         = ref.watch(languageProvider);
    final currencyInfo = ref.watch(currencyProvider);
    final themeId      = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: _phase >= 1 ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Text('Settings',
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 24,
                              color: AppColors.textPrimary)),
                    ),
                  ),
                ),
                // Sections
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        _buildSection(
                          title: 'Account',
                          visible: _phase >= 2,
                          delay: 100,
                          items: [
                            _SettingsItem(
                              icon: '📂',
                              label: 'Categories',
                              sub: 'Manage expense & income categories',
                              onTap: () => setState(() => _showCats = true),
                            ),
                            _SettingsItem(
                              icon: '🔔',
                              label: 'Reminders',
                              sub: 'Bill reminders & notifications',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RemindersScreen()),
                              ),
                            ),
                            _SettingsItem(
                              icon: '🏦',
                              label: 'Accounts',
                              sub: 'BCA, GoPay, SeaBank & more',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AccountsScreen()),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        _buildSection(
                          title: 'Preferences',
                          visible: _phase >= 2,
                          delay: 200,
                          items: [
                            // ── Language ──────────────────────────────────
                            _SettingsItem(
                              icon: '🌐',
                              label: 'Language',
                              sub: 'Coming soon',
                              trailing: _buildLangToggle(lang),
                            ),
                            // ── Currency ──────────────────────────────────
                            _SettingsItem(
                              icon: '💱',
                              label: 'Currency',
                              sub: currencyInfo.displayName,
                              onTap: _showCurrencyPicker,
                            ),
                            // ── Theme ──────────────────────────────────────
                            _SettingsItem(
                              icon: '🎨',
                              label: 'Change Theme',
                              sub: themeId.label,
                              onTap: _showThemePicker,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildSection(
                          title: 'Data',
                          visible: _phase >= 3,
                          delay: 400,
                          items: [
                            _SettingsItem(
                              icon: '🗑️',
                              label: 'Reset App Data',
                              sub: 'Delete all data and start fresh',
                              danger: true,
                              onTap: () => _showResetConfirm(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Version
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: _phase >= 3 ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 0, 100),
                      child: Column(
                        children: [
                          Text('Katonagari',
                              style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 13, color: AppColors.textGhost)),
                          const SizedBox(height: 2),
                          Text('v1.0.0',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10, color: AppColors.textGhost)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category sheet overlay
          if (_showCats)
            _CategorySheet(onClose: () => setState(() => _showCats = false)),
        ],
      ),
    );
  }

  // ── Backup Banner ───────────────────────────────────────────────────────────

  // ── Section ──────────────────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required bool visible,
    required int delay,
    required List<_SettingsItem> items,
  }) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Duration(milliseconds: 300 + delay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDim,
                  letterSpacing: 0.5,
                )),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return Column(
                    children: [
                      if (i > 0)
                        Container(
                          height: 1,
                          color: AppColors.border,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      _buildRow(item),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_SettingsItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: item.danger
                    ? AppColors.expenseRedDim
                    : AppColors.surfaceEl,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.danger
                      ? AppColors.expenseRed.withOpacity(0.15)
                      : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(item.icon, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.danger
                            ? AppColors.expenseRed
                            : AppColors.textPrimary,
                      )),
                  if (item.sub != null) ...[
                    const SizedBox(height: 2),
                    Text(item.sub!,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: AppColors.textDim)),
                  ],
                ],
              ),
            ),
            if (item.trailing != null)
              item.trailing!
            else if (item.onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }

  // ── Language Toggle ──────────────────────────────────────────────────────────
  Widget _buildLangToggle(String currentLang) {
    return Row(
      children: ['en', 'id'].map((l) {
        final active = currentLang == l;
        return GestureDetector(
          onTap: () => ref.read(languageProvider.notifier).setLanguage(l),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? AppColors.accentDim : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: active ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Text(
              l == 'en' ? 'EN' : 'ID',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.accent : AppColors.textDim,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Theme Picker ─────────────────────────────────────────────────────────────
  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ThemePickerSheet(
        currentTheme: ref.read(themeProvider),
        onSelected: (id) {
          ref.read(themeProvider.notifier).setTheme(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── Currency Picker ──────────────────────────────────────────────────────────
  void _showCurrencyPicker() {
    final current = ref.read(currencyProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CurrencyPickerSheet(
        currentCode: current.code,
        onSelected: (code) {
          ref.read(currencyProvider.notifier).setCurrency(code);
          Navigator.of(context).pop();
        },
      ),
    );
  }
  // ── Reset Confirm ────────────────────────────────────────────────────────────
  void _showResetConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceEl,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
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
            const SizedBox(height: 24),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.expenseRedDim,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('🗑️', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 16),
            Text('Reset App Data',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'This will permanently delete all your transactions, budgets, and settings. This cannot be undone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text('Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _resetAppData();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.expenseRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('Reset',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetAppData() async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.delete(db.budgets).go();
      await db.delete(db.transactions).go();
      await db.delete(db.categories).go();
      await db.delete(db.wallets).go();
    });

    await db.into(db.wallets).insert(
      WalletsCompanion.insert(name: 'Cash', balance: const drift.Value(0)),
    );

    final expCats = [
      ('Food','🍜','#E8A87C'), ('Transport','⛽','#7EC8E3'),
      ('Bills','📱','#C4A778'), ('Groceries','🛒','#95D5B2'),
      ('Housing','🏠','#B8A9C9'), ('Entertainment','🎮','#F28482'),
      ('Health','💊','#84DCC6'), ('Shopping','🛍️','#FFB347'),
      ('Education','📚','#87CEEB'), ('Other','📦','#A9A9A9'),
    ];
    for (final c in expCats) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: c.$1, type: 'EXPENSE', icon: c.$2,
        color: drift.Value(c.$3), isDefault: const drift.Value(true),
      ));
    }

    final incCats = [
      ('Salary','💼','#5A9E6F'), ('Freelance','💻','#5A9E6F'),
      ('Business','🏪','#5A9E6F'), ('Other','💰','#5A9E6F'),
    ];
    for (final c in incCats) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: c.$1, type: 'INCOME', icon: c.$2,
        color: drift.Value(c.$3), isDefault: const drift.Value(true),
      ));
    }

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
          content: Text('All data has been reset.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      );
    }
  }
}

// ── Settings Item model ──────────────────────────────────────────────────────
class _SettingsItem {
  final String icon, label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.sub,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
}

// ── Currency Picker Bottom Sheet ─────────────────────────────────────────────
class _CurrencyPickerSheet extends StatelessWidget {
  final String currentCode;
  final ValueChanged<String> onSelected;

  const _CurrencyPickerSheet({
    required this.currentCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceEl,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Currency',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 18, color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          ...PreferencesService.supportedCurrencies.map((c) {
            final isSelected = c.code == currentCode;
            return GestureDetector(
              onTap: () => onSelected(c.code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentDim : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withOpacity(0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(c.symbol,
                          style: GoogleFonts.dmMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(c.displayName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          )),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.accent),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Category Management Sheet ────────────────────────────────────────────────
class _CategorySheet extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const _CategorySheet({required this.onClose});

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  bool _show = false;
  String _tab = 'expense';
  final _nameCtrl = TextEditingController();
  String _selectedIcon = '📦';
  bool _showAddForm = false;
  bool _saving = false;

  final _icons = [
    '🍜','⛽','📱','🛒','🏠','🎮','💊','🛍️','📚','📦',
    '☕','🍕','🎵','🎬','✈️','🐱','🌿','💪','🎯','💡',
    '💼','💻','🏪','💰','📈','🎁','🧴','🔧','📷','🎨',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(categoryRepoProvider);
      await repo.add(CategoriesCompanion.insert(
        name: _nameCtrl.text.trim(),
        type: _tab == 'expense' ? 'EXPENSE' : 'INCOME',
        icon: _selectedIcon,
        isDefault: const drift.Value(false),
      ));
      _nameCtrl.clear();
      setState(() {
        _showAddForm = false;
        _saving = false;
        _selectedIcon = '📦';
      });
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    final repo = ref.read(categoryRepoProvider);
    await repo.delete(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = _tab == 'expense'
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);
    final cats = catsAsync.valueOrNull ?? [];

    return GestureDetector(
      onTap: widget.onClose,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: Colors.black.withOpacity(_show ? 0.5 : 0),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: AnimatedSlide(
              offset: _show ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: AppColors.surfaceEl,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Categories',
                              style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 18, color: AppColors.textPrimary)),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: AppColors.textMuted, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: ['expense', 'income'].map((t) {
                            final active = _tab == t;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _tab = t;
                                  _showAddForm = false;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.accentDim
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: active
                                          ? AppColors.accentMuted
                                          : Colors.transparent,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    t[0].toUpperCase() + t.substring(1),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: active
                                          ? AppColors.accent
                                          : AppColors.textDim,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Add form (expandable)
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        child: _showAddForm
                            ? Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.accentMuted),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('New Category',
                                  style: GoogleFonts.dmSerifDisplay(
                                      fontSize: 14,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 12),

                              Text('Icon',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDim,
                                    letterSpacing: 0.5,
                                  )),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _icons.map((ico) {
                                  final sel = _selectedIcon == ico;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedIcon = ico),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 38, height: 38,
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.accentDim
                                            : AppColors.bg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: sel
                                              ? AppColors.accent
                                              : AppColors.border,
                                          width: sel ? 1.5 : 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(ico,
                                          style: const TextStyle(fontSize: 18)),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 12),

                              Text('Name',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDim,
                                    letterSpacing: 0.5,
                                  )),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: TextField(
                                  controller: _nameCtrl,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'Category name...',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: AppColors.textDim),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    prefixText: '$_selectedIcon  ',
                                    prefixStyle: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _showAddForm = false),
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text('Cancel',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            )),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _saving ? null : _saveCategory,
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: _saving
                                            ? SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.bg,
                                          ),
                                        )
                                            : Text('Save',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.bg,
                                            )),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),

                    // Category list
                    Expanded(
                      child: cats.isEmpty
                          ? Center(
                        child: Text('No categories yet',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: AppColors.textDim)),
                      )
                          : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: cats.length,
                        separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) {
                          final cat = cats[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(cat.icon,
                                      style: const TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          )),
                                      Text(
                                        cat.isDefault ? 'Default' : 'Custom',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: AppColors.textDim),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!cat.isDefault)
                                  GestureDetector(
                                    onTap: () => _deleteCategory(cat),
                                    child: Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(
                                        color: AppColors.expenseRedDim,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.expenseRed.withOpacity(0.15),
                                        ),
                                      ),
                                      child: Icon(Icons.close_rounded,
                                          size: 13,
                                          color: AppColors.expenseRed),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Add button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: GestureDetector(
                        onTap: () => setState(() => _showAddForm = !_showAddForm),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _showAddForm
                                ? AppColors.surface
                                : AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                            border: _showAddForm
                                ? Border.all(color: AppColors.border)
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showAddForm
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.add_rounded,
                                color: _showAddForm
                                    ? AppColors.textMuted
                                    : AppColors.bg,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showAddForm ? 'Collapse' : 'Add Custom Category',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _showAddForm
                                      ? AppColors.textMuted
                                      : AppColors.bg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Theme Picker Bottom Sheet ─────────────────────────────────────────────────
class _ThemePickerSheet extends StatelessWidget {
  final AppThemeId            currentTheme;
  final ValueChanged<AppThemeId> onSelected;

  const _ThemePickerSheet({
    required this.currentTheme,
    required this.onSelected,
  });

  // Swatch colors for each theme (bg, surface, accent) — hardcoded so they
  // always render correctly regardless of the currently active theme.
  static const _swatches = {
    AppThemeId.obsidianGold:     [Color(0xFF0D0D0D), Color(0xFF141414), Color(0xFFC4A778)],
    AppThemeId.midnightSapphire: [Color(0xFF090E1A), Color(0xFF0F1726), Color(0xFF4A90D9)],
    AppThemeId.forestDusk:       [Color(0xFF090F0D), Color(0xFF0F1A16), Color(0xFF3DAF80)],
    AppThemeId.chalkInk:         [Color(0xFFF5F2EC), Color(0xFFEDE9E1), Color(0xFF9B7B3A)],
    AppThemeId.roseQuartz:       [Color(0xFFFAF4F5), Color(0xFFF3E8EA), Color(0xFFC46880)],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            children: [
              Text('Choose Theme',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 20, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Changes apply instantly across the entire app',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 18),

          // Theme cards
          ...AppThemeId.values.map((id) {
            final isSelected = id == currentTheme;
            final colors     = _swatches[id]!;
            final bgColor    = colors[0];
            final sfColor    = colors[1];
            final acColor    = colors[2];
            final isDark     = id.isDark;

            final textOnBg   = isDark
                ? const Color(0xFFE8E0D8)
                : const Color(0xFF1A1612);
            final subOnBg    = isDark
                ? const Color(0xFF6A6058)
                : const Color(0xFF8A7D6A);

            return GestureDetector(
              onTap: () => onSelected(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color:        isSelected
                      ? AppColors.accentDim
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Mini palette preview
                    Container(
                      width: 80, height: 68,
                      decoration: BoxDecoration(
                        color:        bgColor,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(13)),
                      ),
                      child: Stack(
                        children: [
                          // Surface strip
                          Positioned(
                            left: 14, top: 14, right: 14,
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color:        sfColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Accent dot + mini bar
                                  Container(
                                    width: 7, height: 7,
                                    decoration: BoxDecoration(
                                      color:  acColor,
                                      shape:  BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    width: 22, height: 4,
                                    decoration: BoxDecoration(
                                      color:        acColor.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom accent bar
                          Positioned(
                            left: 14, bottom: 12, right: 14,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color:        acColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Labels
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(id.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.textPrimary,
                                  )),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: id.isDark
                                      ? AppColors.borderStrong
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  id.isDark ? 'dark' : 'light',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9, fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(id.description,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppColors.textMuted,
                              )),
                        ],
                      ),
                    ),

                    // Check / chevron
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: isSelected
                          ? Icon(Icons.check_circle_rounded,
                          color: AppColors.accent, size: 20)
                          : Icon(Icons.radio_button_unchecked_rounded,
                          color: AppColors.border, size: 20),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
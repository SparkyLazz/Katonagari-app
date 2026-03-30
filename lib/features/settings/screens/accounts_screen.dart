import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/database/app_database.dart';

// ─────────────────────────────────────────────────────────
//  AccountsScreen
// ─────────────────────────────────────────────────────────
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showAddForm = false;
  bool _saving      = false;

  final _nameCtrl    = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _selectedIcon = '💳';

  final _icons = [
    '💳','🏦','💵','📱','🏧','💰','👛','🪙','💎','🏪',
    '🛒','✈️','🏠','🚗','🌿','🎯','💼','📈','🎁','🔧',
  ];

  final _presets = [
    ('BCA',       '🏦'),
    ('Mandiri',   '🏦'),
    ('BNI',       '🏦'),
    ('BRI',       '🏦'),
    ('SeaBank',   '📱'),
    ('GoPay',     '📱'),
    ('OVO',       '📱'),
    ('Dana',      '📱'),
    ('ShopeePay', '📱'),
    ('Tunai',     '💵'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _fillPreset(String name, String icon) {
    setState(() {
      _nameCtrl.text = name;
      _selectedIcon  = icon;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final balance = double.tryParse(
              _balanceCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
          0;
      await ref.read(walletRepoProvider).add(
            WalletsCompanion.insert(
              name:    name,
              icon:    drift.Value(_selectedIcon),
              balance: drift.Value(balance),
            ),
          );
      _nameCtrl.clear();
      _balanceCtrl.clear();
      setState(() {
        _showAddForm  = false;
        _selectedIcon = '💳';
        _saving       = false;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete(Wallet wallet) async {
    final count = await ref.read(walletRepoProvider).transactionCount(wallet.id);
    if (!mounted) return;

    if (count > 0) {
      _showDeleteBlockedDialog(wallet.name, count);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceEl,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete account?',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 18, color: AppColors.textPrimary)),
        content: Text(
          'Remove "${wallet.name}" from your accounts.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.expenseRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(walletRepoProvider).delete(wallet.id);
    }
  }

  void _showDeleteBlockedDialog(String name, int count) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceEl,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Cannot delete',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 18, color: AppColors.textPrimary)),
        content: Text(
          '"$name" has $count transaction${count == 1 ? '' : 's'} linked to it. '
          'Please delete those transactions first.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(Wallet wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditWalletSheet(wallet: wallet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletProvider);
    final wallets      = walletsAsync.valueOrNull ?? [];
    final cur          = ref.currency; // ← read once, passed down

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                  Expanded(
                    child: Text('Accounts',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 22, color: AppColors.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAddForm = !_showAddForm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _showAddForm
                            ? AppColors.surface
                            : AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _showAddForm ? 'Cancel' : '+ Add',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _showAddForm
                              ? AppColors.textSecondary
                              : AppColors.bg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showAddForm
                        ? _buildAddForm(cur)
                        : const SizedBox.shrink(),
                  ),

                  if (wallets.isEmpty && !_showAddForm)
                    _buildEmptyState()
                  else
                    ...wallets.map((w) => _buildWalletTile(w, cur)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('🏦', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('No accounts yet',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Tap "+ Add" to create your first account.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Wallet Tile ──────────────────────────────────────────────────────────────
  Widget _buildWalletTile(Wallet wallet, CurrencyInfo cur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        AppColors.surfaceEl,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(wallet.icon,
              style: const TextStyle(fontSize: 22)),
        ),
        title: Text(
          wallet.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: wallet.balance > 0
            ? Text(
                // ← was _fmtRp(wallet.balance)
                'Balance : ${cur.format(wallet.balance)}',
                style: GoogleFonts.dmMono(
                    fontSize: 11, color: AppColors.textMuted),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showEditSheet(wallet),
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.textMuted, size: 20),
            ),
            IconButton(
              onPressed: () => _delete(wallet),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.expenseRed, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add Form ─────────────────────────────────────────────────────────────────
  Widget _buildAddForm(CurrencyInfo cur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Account',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          // Preset chips
          Text('QUICK PICK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 1.2,
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              return GestureDetector(
                onTap: () => _fillPreset(p.$1, p.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _nameCtrl.text == p.$1
                        ? AppColors.accentDim
                        : AppColors.surfaceEl,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _nameCtrl.text == p.$1
                          ? AppColors.accent
                          : AppColors.border,
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
                            color: _nameCtrl.text == p.$1
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Name field
          Text('NAME',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 1.2,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. BCA, GoPay, Dompet…',
              hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.surfaceEl,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 14),

          // Initial balance
          Text('INITIAL BALANCE (optional)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 1.2,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.dmMono(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '0',
              // ← was hardcoded 'Rp '
              prefixText: '${cur.symbol} ',
              prefixStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500),
              hintStyle: GoogleFonts.dmMono(
                  fontSize: 14, color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.surfaceEl,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 14),

          // Icon picker
          Text('ICON',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textDim, letterSpacing: 1.2,
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentDim
                        : AppColors.surfaceEl,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon,
                      style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Save button
          GestureDetector(
            onTap: _saving || _nameCtrl.text.trim().isEmpty ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _nameCtrl.text.trim().isEmpty
                    ? AppColors.borderStrong
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.bg),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_selectedIcon,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'Save Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _nameCtrl.text.trim().isEmpty
                                ? AppColors.textDim
                                : AppColors.bg,
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
}

// ─────────────────────────────────────────────────────────
//  Edit Wallet Bottom Sheet
// ─────────────────────────────────────────────────────────
class _EditWalletSheet extends ConsumerStatefulWidget {
  final Wallet wallet;
  const _EditWalletSheet({required this.wallet});

  @override
  ConsumerState<_EditWalletSheet> createState() => _EditWalletSheetState();
}

class _EditWalletSheetState extends ConsumerState<_EditWalletSheet> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  bool _saving = false;

  final _icons = [
    '💳','🏦','💵','📱','🏧','💰','👛','🪙','💎','🏪',
    '🛒','✈️','🏠','🚗','🌿','🎯','💼','📈','🎁','🔧',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wallet.name);
    _icon     = widget.wallet.icon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(walletRepoProvider).update(
            widget.wallet.toCompanion(false).copyWith(
              name: drift.Value(name),
              icon: drift.Value(_icon),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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

          Text('Edit Account',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 18, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtrl,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Account name',
              hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon == _icon;
              return GestureDetector(
                onTap: () => setState(() => _icon = icon),
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
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon,
                      style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color:        AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.bg),
                    )
                  : Text('Save',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.bg,
                      )),
            ),
          ),
        ],
      ),
    );
  }
}
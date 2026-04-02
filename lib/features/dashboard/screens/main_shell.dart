import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'add_transaction_sheet.dart';
import '../../history/screens/history_screen.dart';
import '../../insights/screens/insights_screen.dart';
import '../../debts/screens/debt_screen.dart';
import '../../settings/screens/settings_screen.dart';

// ─────────────────────────────────────────────────────
//  Tab definition
// ─────────────────────────────────────────────────────
class _TabDef {
  final int     index;
  final String  label;
  final IconData icon;
  final Widget  screen;
  const _TabDef({
    required this.index,
    required this.label,
    required this.icon,
    required this.screen,
  });
}

final List<_TabDef> _allTabs = [
  _TabDef(index: 0, label: 'Home',     icon: Icons.home_rounded,           screen: const DashboardScreen()),
  _TabDef(index: 1, label: 'History',  icon: Icons.receipt_long_rounded,   screen: const HistoryScreen()),
  _TabDef(index: 2, label: 'Insights', icon: Icons.bar_chart_rounded,      screen: const InsightsScreen()),
  _TabDef(index: 3, label: 'Debts',    icon: Icons.handshake_outlined,     screen: const DebtScreen()),
  _TabDef(index: 4, label: 'Settings', icon: Icons.settings_rounded,       screen: const SettingsScreen()),
];

// First 3 are always pinned in the nav bar.
// Tabs 3+ are accessible via the "More" picker.
const int _pinnedCount = 3;

// ─────────────────────────────────────────────────────
//  MainShell
// ─────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _activeTab = 0;
  late AnimationController _fabCtrl;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fabCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _activeTab = index);
  }

  void _openMorePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MorePickerSheet(
        tabs:      _allTabs,
        activeTab: _activeTab,
        onSelect:  (i) {
          Navigator.pop(context);
          _onTabChanged(i);
        },
      ),
    );
  }

  void _showSavedToast(Map<String, dynamic> data) {
    final isIncome = data['type'] == 'income';
    final amount = (data['amount'] as double)
        .toStringAsFixed(0)
        .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: AppColors.surfaceEl,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderStrong),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: isIncome
                    ? AppColors.incomeGreenDim
                    : AppColors.expenseRedDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_rounded,
                  color: AppColors.incomeGreen, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Saved!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  Text(
                    '${isIncome ? "+" : "−"}Rp $amount · ${data['catName']}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              child: Text('Undo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the active tab is a "more" tab (index >= _pinnedCount)
    final isMoreActive = _activeTab >= _pinnedCount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _activeTab,
        children: _allTabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: _BottomNav(
        tabs:         _allTabs,
        activeTab:    _activeTab,
        isMoreActive: isMoreActive,
        onTabChanged: _onTabChanged,
        onMoreTap:    _openMorePicker,
        fabAnim:      _fabCtrl,
        onFabTap: () async {
          final result = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const AddTransactionSheet(),
          );
          if (result != null && mounted) {
            _showSavedToast(result);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Bottom Nav
// ─────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final List<_TabDef>        tabs;
  final int                  activeTab;
  final bool                 isMoreActive;
  final ValueChanged<int>    onTabChanged;
  final VoidCallback         onMoreTap;
  final AnimationController  fabAnim;
  final VoidCallback         onFabTap;

  const _BottomNav({
    required this.tabs,
    required this.activeTab,
    required this.isMoreActive,
    required this.onTabChanged,
    required this.onMoreTap,
    required this.fabAnim,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final pinned = tabs.take(_pinnedCount).toList();

    return Container(
      decoration: BoxDecoration(
        color:  AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ── Left side: first 2 pinned tabs ──
              Positioned(
                left: 0,
                width: MediaQuery.of(context).size.width / 2 - 36,
                child: Row(
                  children: List.generate(2, (i) => Expanded(
                    child: _NavItem(
                      tab:      pinned[i],
                      isActive: activeTab == pinned[i].index,
                      onTap:    () => onTabChanged(pinned[i].index),
                    ),
                  )),
                ),
              ),

              // ── Center FAB ──
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: fabAnim,
                  curve: Curves.elasticOut,
                ),
                child: GestureDetector(
                  onTap: onFabTap,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color:  AppColors.accent,
                      shape:  BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color:      AppColors.accent.withOpacity(0.35),
                          blurRadius: 20,
                          offset:     const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.add, color: AppColors.bg, size: 26),
                  ),
                ),
              ),

              // ── Right side: 3rd pinned tab + More button ──
              Positioned(
                right: 0,
                width: MediaQuery.of(context).size.width / 2 - 36,
                child: Row(
                  children: [
                    // 3rd pinned tab (index 2)
                    Expanded(
                      child: _NavItem(
                        tab:      pinned[2],
                        isActive: activeTab == pinned[2].index,
                        onTap:    () => onTabChanged(pinned[2].index),
                      ),
                    ),
                    // More button
                    Expanded(
                      child: _MoreButton(
                        isActive:    isMoreActive,
                        activeLabel: isMoreActive
                            ? tabs[activeTab].label
                            : null,
                        onTap: onMoreTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Nav Item
// ─────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final _TabDef  tab;
  final bool     isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color:        isActive ? AppColors.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                tab.icon,
                size:  20,
                color: isActive ? AppColors.accent : AppColors.textDim,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.plusJakartaSans(
                fontSize:   10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color:      isActive ? AppColors.accent : AppColors.textDim,
              ),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  More Button
// ─────────────────────────────────────────────────────
class _MoreButton extends StatelessWidget {
  final bool    isActive;
  final String? activeLabel;
  final VoidCallback onTap;

  const _MoreButton({
    required this.isActive,
    required this.activeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color:        isActive ? AppColors.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive
                    ? Icons.grid_view_rounded
                    : Icons.more_horiz_rounded,
                size:  20,
                color: isActive ? AppColors.accent : AppColors.textDim,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.plusJakartaSans(
                fontSize:   10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color:      isActive ? AppColors.accent : AppColors.textDim,
              ),
              child: Text(
                isActive && activeLabel != null ? activeLabel! : 'More',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  More Picker Sheet
// ─────────────────────────────────────────────────────
class _MorePickerSheet extends StatelessWidget {
  final List<_TabDef>     tabs;
  final int               activeTab;
  final ValueChanged<int> onSelect;

  const _MorePickerSheet({
    required this.tabs,
    required this.activeTab,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Only show the "overflow" tabs (index >= _pinnedCount)
    final overflowTabs = tabs.skip(_pinnedCount).toList();

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceEl,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Title
          Text('More',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 20, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Tap a screen to navigate',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textDim)),
          const SizedBox(height: 20),

          // Grid of overflow tabs
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap:     true,
            physics:        const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
            childAspectRatio: 1.1,
            children: overflowTabs.map((tab) {
              final isActive = activeTab == tab.index;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(tab.index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accentDim
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? AppColors.accentMuted
                          : AppColors.border,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size:  26,
                        color: isActive
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tab.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize:   12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Divider + pinned screens reminder
          const SizedBox(height: 20),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          Text('Pinned',
              style: GoogleFonts.plusJakartaSans(
                fontSize:    11,
                fontWeight:  FontWeight.w600,
                color:       AppColors.textDim,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 12),
          Row(
            children: tabs.take(_pinnedCount).map((tab) {
              final isActive = activeTab == tab.index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(tab.index);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accentDim
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? AppColors.accentMuted
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          tab.icon,
                          size:  18,
                          color: isActive
                              ? AppColors.accent
                              : AppColors.textDim,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:  10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.accent
                                : AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
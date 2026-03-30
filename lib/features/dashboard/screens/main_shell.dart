import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'add_transaction_sheet.dart';
import '../../history/screens/history_screen.dart';
import '../../insights/screens/insights_screen.dart';
import '../../settings/screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _activeTab = 0;
  late AnimationController _fabCtrl;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HistoryScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

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
          side: const BorderSide(color: AppColors.borderStrong),
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
              child: const Icon(Icons.check_rounded,
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _activeTab,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        activeTab: _activeTab,
        onTabChanged: (i) => setState(() => _activeTab = i),
        fabAnim: _fabCtrl,
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

// ── Bottom Nav with center FAB ──
class _BottomNav extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final AnimationController fabAnim;
  final VoidCallback onFabTap;

  const _BottomNav({
    required this.activeTab,
    required this.onTabChanged,
    required this.fabAnim,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _NavTab(label: 'Home',     icon: Icons.home_rounded),
      const _NavTab(label: 'History',  icon: Icons.receipt_long_rounded),
      const _NavTab(label: 'Insights', icon: Icons.bar_chart_rounded),
      const _NavTab(label: 'Settings', icon: Icons.settings_rounded),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Nav items row
              Row(
                children: [
                  ...List.generate(2, (i) => Expanded(
                    child: _NavItem(
                      tab: tabs[i],
                      isActive: activeTab == i,
                      onTap: () => onTabChanged(i),
                    ),
                  )),
                  const SizedBox(width: 72),
                  ...List.generate(2, (i) => Expanded(
                    child: _NavItem(
                      tab: tabs[i + 2],
                      isActive: activeTab == i + 2,
                      onTap: () => onTabChanged(i + 2),
                    ),
                  )),
                ],
              ),

              // Center FAB
              Positioned(
                top: 0,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: fabAnim,
                    curve: Curves.elasticOut,
                  ),
                  child: GestureDetector(
                    onTap: onFabTap,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add,
                          color: AppColors.bg, size: 26),
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
}

// ── Nav Tab model ──
class _NavTab {
  final String label;
  final IconData icon;
  const _NavTab({required this.label, required this.icon});
}

// ── Nav Item widget ──
class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tab.icon,
            size: 20,
            color: isActive ? AppColors.accent : AppColors.textDim,
          ),
          const SizedBox(height: 3),
          Text(
            tab.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.accent : AppColors.textDim,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 4 : 0,
            height: isActive ? 4 : 0,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
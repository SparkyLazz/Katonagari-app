import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/launch_service.dart';
import '../../../core/services/preferences_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int    _currentPage      = 0;
  String _selectedCurrency = 'IDR';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // ── Save the selected currency to the provider before navigating ──
      ref.read(currencyProvider.notifier).setCurrency(_selectedCurrency);
      LaunchService.markLaunched().then((_) {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // Page indicator
              Padding(
                padding: const EdgeInsets.only(top: 20, right: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(
                      2, (i) => _DotIndicator(active: i == _currentPage)),
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _PageHook(onContinue: _nextPage),
                    _PageSell(
                      selectedCurrency:  _selectedCurrency,
                      onCurrencyChanged: (c) =>
                          setState(() => _selectedCurrency = c),
                      onStart: _nextPage,
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

// ── Dot Indicator ─────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final bool active;
  const _DotIndicator({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(left: 6),
      width:  active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color:        active ? AppColors.accent : AppColors.borderStrong,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PAGE 1 — The Hook
// ─────────────────────────────────────────
class _PageHook extends StatelessWidget {
  final VoidCallback onContinue;
  const _PageHook({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          Text(
            '3 taps to log.\nZero leaves your phone.',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 30,
              color:    AppColors.textPrimary,
              height:   1.25,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'All data stays on your device.\nNo accounts, no cloud, no ads.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color:    AppColors.textMuted,
              height:   1.6,
            ),
          ),

          const SizedBox(height: 32),

          _PreviewCard(),

          const Spacer(),

          _GoldButton(label: 'Continue', onTap: onContinue),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Fake Dashboard Preview Card ───────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mar 2026',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
              Text('Today −Rp 67.000',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 11, color: AppColors.expenseRed)),
            ],
          ),

          const SizedBox(height: 12),

          Text('Rp 4.250.000',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 28, color: AppColors.textPrimary)),

          const SizedBox(height: 4),

          Text('↓ 12% vs Feb',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.expenseRed,
                  fontWeight: FontWeight.w600)),

          const SizedBox(height: 16),

          _FakeTxRow(
              icon: '💼',
              name: 'Gaji Maret',
              amount: '+6.500.000',
              isIncome: true),
          const SizedBox(height: 8),
          _FakeTxRow(
              icon: '🏠',
              name: 'Kos Bulanan',
              amount: '−1.200.000',
              isIncome: false),
          const SizedBox(height: 8),
          _FakeTxRow(
              icon: '🍜',
              name: 'Mie Ayam Pak Budi',
              amount: '−15.000',
              isIncome: false),
        ],
      ),
    );
  }
}

class _FakeTxRow extends StatelessWidget {
  final String icon, name, amount;
  final bool   isIncome;
  const _FakeTxRow({
    required this.icon,
    required this.name,
    required this.amount,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        AppColors.surfaceEl,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis),
        ),
        Text(amount,
            style: GoogleFonts.dmMono(
              fontSize: 12,
              color: isIncome
                  ? AppColors.incomeGreen
                  : AppColors.expenseRed,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────
// PAGE 2 — The Sell
// ─────────────────────────────────────────
class _PageSell extends StatelessWidget {
  final String              selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback        onStart;

  const _PageSell({
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          Text(
            'Built for how you\nactually spend.',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 30,
              color:    AppColors.textPrimary,
              height:   1.25,
            ),
          ),

          const SizedBox(height: 32),

          _FeatureCard(
            icon:     '⚡',
            title:    '3-tap quick add',
            subtitle: 'Amount → category → save. Done in seconds.',
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            icon:     '🔒',
            title:    '100% offline',
            subtitle: 'Your data never leaves your phone. Ever.',
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            icon:     '📊',
            title:    'Know your patterns',
            subtitle: 'See where your money actually goes each month.',
          ),

          const SizedBox(height: 28),

          Text(
            'YOUR CURRENCY',
            style: GoogleFonts.plusJakartaSans(
              fontSize:    10,
              color:       AppColors.textMuted,
              fontWeight:  FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 10),

          // ── Show all supported currencies from PreferencesService ──
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PreferencesService.supportedCurrencies.map((c) {
              final selected = c.code == selectedCurrency;
              return GestureDetector(
                onTap: () => onCurrencyChanged(c.code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.symbol,
                          style: GoogleFonts.dmMono(
                            fontSize:   12,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 6),
                      Text(c.code,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:  12,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const Spacer(),

          _GoldButton(label: 'Start Tracking', onTap: onStart),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String icon, title, subtitle;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        AppColors.accentDim,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   13,
                      color:      AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color:    AppColors.textMuted,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Gold Button ──────────────────────────────────────────────────────
class _GoldButton extends StatelessWidget {
  final String     label;
  final VoidCallback onTap;
  const _GoldButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color:        AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize:   15,
            fontWeight: FontWeight.w700,
            color:      AppColors.bg,
          ),
        ),
      ),
    );
  }
}
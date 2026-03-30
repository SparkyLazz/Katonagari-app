import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final bool isFirstLaunch;
  const SplashScreen({super.key, required this.isFirstLaunch});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowOpacity;

  late AnimationController _logoCtrl;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  late AnimationController _nameCtrl;
  late Animation<double> _nameOpacity;

  late AnimationController _tagCtrl;
  late Animation<double> _tagOpacity;

  late AnimationController _exitCtrl;
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowOpacity = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

    _nameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _nameOpacity = CurvedAnimation(parent: _nameCtrl, curve: Curves.easeOut);

    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tagOpacity = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
  await Future.delayed(const Duration(milliseconds: 100));
  _glowCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 200));
  _logoCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 300));
  _nameCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 400));
  _tagCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 1400));
  _exitCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 400));
  if (mounted) {
    // ← Route based on first launch
    if (widget.isFirstLaunch) {
      context.go('/onboarding');
    } else {
      context.go('/dashboard');
    }
  }
}

  @override
  void dispose() {
    _glowCtrl.dispose();
    _logoCtrl.dispose();
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Stack(
          fit: StackFit.expand,        // ← fills full screen
          alignment: Alignment.center,
          children: [
            // ── Radial glow ──
            Center(
              child: FadeTransition(
                opacity: _glowOpacity,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.12),
                        AppColors.accent.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Logo + Name + Tagline ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo box
                  SlideTransition(
                    position: _logoSlide,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'K',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 42,
                            color: AppColors.accent,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App name
                  FadeTransition(
                    opacity: _nameOpacity,
                    child: Text(
                      'Katonagari',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 28,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  FadeTransition(
                    opacity: _tagOpacity,
                    child: Text(
                      'KNOW YOUR MONEY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.08 * 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
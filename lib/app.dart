import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/providers.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/dashboard/screens/main_shell.dart';

class KatonagariApp extends ConsumerStatefulWidget {
  final bool isFirstLaunch;
  const KatonagariApp({super.key, required this.isFirstLaunch});

  @override
  ConsumerState<KatonagariApp> createState() => _KatonagariAppState();
}

class _KatonagariAppState extends ConsumerState<KatonagariApp> {
  // Created once — rebuilding it on every theme/language change would reset
  // navigation back to the splash screen.
  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => SplashScreen(isFirstLaunch: widget.isFirstLaunch),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const MainShell(),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(languageProvider);
    final themeId = ref.watch(themeProvider);

    // Sync AppColors static accessors whenever theme changes
    AppColors.apply(AppThemeSchemes.forTheme(themeId));

    return MaterialApp.router(
      title: 'Katonagari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildFrom(AppThemeSchemes.forTheme(themeId)),
      routerConfig: _router,
      builder: (_, child) =>
          _ThemeRefresh(themeId: themeId, child: child ?? const SizedBox()),

      // ── Locale ──────────────────────────────────────────
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('id')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Widgets read colors from the static [AppColors] accessors, so they don't
/// rebuild by themselves when the theme changes. This marks the whole subtree
/// dirty once per theme switch so every screen (and open route) repaints with
/// the new scheme without losing its state.
class _ThemeRefresh extends StatefulWidget {
  final AppThemeId themeId;
  final Widget child;
  const _ThemeRefresh({required this.themeId, required this.child});

  @override
  State<_ThemeRefresh> createState() => _ThemeRefreshState();
}

class _ThemeRefreshState extends State<_ThemeRefresh> {
  @override
  void didUpdateWidget(covariant _ThemeRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeId != widget.themeId) {
      void markDirty(Element el) {
        el.markNeedsBuild();
        el.visitChildren(markDirty);
      }
      (context as Element).visitChildren(markDirty);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

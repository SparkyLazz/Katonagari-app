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

class KatonagariApp extends ConsumerWidget {
  final bool isFirstLaunch;
  const KatonagariApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang    = ref.watch(languageProvider);
    final themeId = ref.watch(themeProvider);

    // Sync AppColors static accessors whenever theme changes
    AppColors.apply(AppThemeSchemes.forTheme(themeId));

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => SplashScreen(isFirstLaunch: isFirstLaunch),
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

    return MaterialApp.router(
      title: 'Katonagari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildFrom(AppThemeSchemes.forTheme(themeId)),
      routerConfig: router,

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
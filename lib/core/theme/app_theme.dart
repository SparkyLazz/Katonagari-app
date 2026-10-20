import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData buildFrom(AppColorScheme s) {
    final brightness = s.isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: s.bg,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ).apply(
        bodyColor:    s.textPrimary,
        displayColor: s.textPrimary,
      ),
      colorScheme: ColorScheme(
        brightness:  brightness,
        background:  s.bg,
        surface:     s.surface,
        primary:     s.accent,
        onPrimary:   s.bg,
        secondary:   s.accent,
        onSecondary: s.bg,
        error:       s.expenseRed,
        onError:     s.bg,
        onBackground: s.textPrimary,
        onSurface:    s.textPrimary,
      ),
      splashColor:    Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor:   s.border,
      cardColor:      s.surface,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:  s.surfaceEl,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  s.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:                    Colors.transparent,
          statusBarIconBrightness:           s.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:               s.isDark ? Brightness.dark  : Brightness.light,
          systemNavigationBarColor:          s.bg,
          systemNavigationBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  s.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor:   Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  /// Theme for date/time pickers that follows the active (light or dark) scheme.
  static ThemeData picker(BuildContext ctx) {
    final base = Theme.of(ctx);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
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
    );
  }

  // Keep a convenience getter for the default dark theme (used by splash etc.)
  static ThemeData get dark => buildFrom(AppThemeSchemes.obsidianGold);
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // ← add this
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,

    // ✅ Add this block
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),

    colorScheme: const ColorScheme.dark(
      background:   AppColors.bg,
      surface:      AppColors.surface,
      primary:      AppColors.accent,
      onPrimary:    AppColors.bg,
      secondary:    AppColors.accent,
      onSecondary:  AppColors.bg,
      error:        AppColors.expenseRed,
      onBackground: AppColors.textPrimary,
      onSurface:    AppColors.textPrimary,
    ),
    splashColor:         Colors.transparent,
    highlightColor:      Colors.transparent,
    dividerColor:        AppColors.border,
    cardColor:           AppColors.surface,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:    AppColors.surfaceEl,
      surfaceTintColor:   Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:    AppColors.bg,
      surfaceTintColor:   Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:              Colors.transparent,
        statusBarIconBrightness:     Brightness.light,
        systemNavigationBarColor:    AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:      AppColors.bg,
      surfaceTintColor:     Colors.transparent,
      indicatorColor:       Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.plusJakartaSans( // ✅ fix nav label font too
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
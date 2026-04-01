import 'package:flutter/material.dart';

// ── Theme identifier ──────────────────────────────────────────────────────────
enum AppThemeId {
  obsidianGold,    // default dark  – warm gold on deep black
  midnightSapphire,// dark          – electric blue on navy
  forestDusk,      // dark          – mint green on charcoal-green
  chalkInk,        // light         – amber ink on warm parchment
  roseQuartz,      // light         – dusty rose on blush white
}

extension AppThemeIdX on AppThemeId {
  String get label => switch (this) {
    AppThemeId.obsidianGold     => 'Obsidian Gold',
    AppThemeId.midnightSapphire => 'Midnight Sapphire',
    AppThemeId.forestDusk       => 'Forest Dusk',
    AppThemeId.chalkInk         => 'Chalk & Ink',
    AppThemeId.roseQuartz       => 'Rose Quartz',
  };

  String get description => switch (this) {
    AppThemeId.obsidianGold     => 'Rich black with warm gold',
    AppThemeId.midnightSapphire => 'Deep navy with electric blue',
    AppThemeId.forestDusk       => 'Dark green with mint accents',
    AppThemeId.chalkInk         => 'Parchment with amber ink',
    AppThemeId.roseQuartz       => 'Blush white with dusty rose',
  };

  bool get isDark => switch (this) {
    AppThemeId.obsidianGold     => true,
    AppThemeId.midnightSapphire => true,
    AppThemeId.forestDusk       => true,
    AppThemeId.chalkInk         => false,
    AppThemeId.roseQuartz       => false,
  };

  String get storageKey => name;
}

// ── Color scheme for one theme ────────────────────────────────────────────────
class AppColorScheme {
  final Color bg;
  final Color surface;
  final Color surfaceEl;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color accentDim;
  final Color accentMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDim;
  final Color textGhost;
  final Color incomeGreen;
  final Color incomeGreenDim;
  final Color expenseRed;
  final Color expenseRedDim;
  final bool  isDark;

  const AppColorScheme({
    required this.bg,
    required this.surface,
    required this.surfaceEl,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentDim,
    required this.accentMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDim,
    required this.textGhost,
    required this.incomeGreen,
    required this.incomeGreenDim,
    required this.expenseRed,
    required this.expenseRedDim,
    required this.isDark,
  });
}

// ── All 5 schemes ─────────────────────────────────────────────────────────────
class AppThemeSchemes {
  AppThemeSchemes._();

  // 1. Obsidian Gold (original default)
  static const AppColorScheme obsidianGold = AppColorScheme(
    bg:            Color(0xFF0D0D0D),
    surface:       Color(0xFF141414),
    surfaceEl:     Color(0xFF1A1A1A),
    border:        Color(0xFF1E1E1E),
    borderStrong:  Color(0xFF2A2A2A),
    accent:        Color(0xFFC4A778),
    accentDim:     Color(0x1AC4A778),
    accentMuted:   Color(0x40C4A778),
    textPrimary:   Color(0xFFF0EBE0),
    textSecondary: Color(0xFFD0C8B8),
    textMuted:     Color(0xFF7A7060),
    textDim:       Color(0xFF3E3830),
    textGhost:     Color(0xFF2E2A26),
    incomeGreen:    Color(0xFF5A9E6F),
    incomeGreenDim: Color(0x1F5A9E6F),
    expenseRed:     Color(0xFFC45A5A),
    expenseRedDim:  Color(0x1FC45A5A),
    isDark: true,
  );

  // 2. Midnight Sapphire
  static const AppColorScheme midnightSapphire = AppColorScheme(
    bg:            Color(0xFF090E1A),
    surface:       Color(0xFF0F1726),
    surfaceEl:     Color(0xFF162035),
    border:        Color(0xFF1C2840),
    borderStrong:  Color(0xFF253655),
    accent:        Color(0xFF4A90D9),
    accentDim:     Color(0x1A4A90D9),
    accentMuted:   Color(0x404A90D9),
    textPrimary:   Color(0xFFE8EEF8),
    textSecondary: Color(0xFFB8C8E0),
    textMuted:     Color(0xFF4A6080),
    textDim:       Color(0xFF253350),
    textGhost:     Color(0xFF1A2540),
    incomeGreen:    Color(0xFF3BAF6A),
    incomeGreenDim: Color(0x1F3BAF6A),
    expenseRed:     Color(0xFFE05555),
    expenseRedDim:  Color(0x1FE05555),
    isDark: true,
  );

  // 3. Forest Dusk
  static const AppColorScheme forestDusk = AppColorScheme(
    bg:            Color(0xFF090F0D),
    surface:       Color(0xFF0F1A16),
    surfaceEl:     Color(0xFF162420),
    border:        Color(0xFF1C3028),
    borderStrong:  Color(0xFF253D32),
    accent:        Color(0xFF3DAF80),
    accentDim:     Color(0x1A3DAF80),
    accentMuted:   Color(0x403DAF80),
    textPrimary:   Color(0xFFDFF0E8),
    textSecondary: Color(0xFFB0D8C4),
    textMuted:     Color(0xFF3A6050),
    textDim:       Color(0xFF1E3828),
    textGhost:     Color(0xFF162C20),
    incomeGreen:    Color(0xFF5AC89A),
    incomeGreenDim: Color(0x1F5AC89A),
    expenseRed:     Color(0xFFD96060),
    expenseRedDim:  Color(0x1FD96060),
    isDark: true,
  );

  // 4. Chalk & Ink (light)
  static const AppColorScheme chalkInk = AppColorScheme(
    bg:            Color(0xFFF5F2EC),
    surface:       Color(0xFFEDE9E1),
    surfaceEl:     Color(0xFFE4DED4),
    border:        Color(0xFFD8D0C4),
    borderStrong:  Color(0xFFC8BEB0),
    accent:        Color(0xFF9B7B3A),
    accentDim:     Color(0x1A9B7B3A),
    accentMuted:   Color(0x409B7B3A),
    textPrimary:   Color(0xFF1A1612),
    textSecondary: Color(0xFF3A3028),
    textMuted:     Color(0xFF8A7D6A),
    textDim:       Color(0xFFB8AEA0),
    textGhost:     Color(0xFFCEC6B8),
    incomeGreen:    Color(0xFF2E8B57),
    incomeGreenDim: Color(0x1F2E8B57),
    expenseRed:     Color(0xFFC0392B),
    expenseRedDim:  Color(0x1FC0392B),
    isDark: false,
  );

  // 5. Rose Quartz (light)
  static const AppColorScheme roseQuartz = AppColorScheme(
    bg:            Color(0xFFFAF4F5),
    surface:       Color(0xFFF3E8EA),
    surfaceEl:     Color(0xFFEBD8DC),
    border:        Color(0xFFE0C8CC),
    borderStrong:  Color(0xFFD4B4BA),
    accent:        Color(0xFFC46880),
    accentDim:     Color(0x1AC46880),
    accentMuted:   Color(0x40C46880),
    textPrimary:   Color(0xFF1E1215),
    textSecondary: Color(0xFF3E2830),
    textMuted:     Color(0xFF9A6878),
    textDim:       Color(0xFFBFA0A8),
    textGhost:     Color(0xFFD4BEC2),
    incomeGreen:    Color(0xFF3A9E6A),
    incomeGreenDim: Color(0x1F3A9E6A),
    expenseRed:     Color(0xFFC44A4A),
    expenseRedDim:  Color(0x1FC44A4A),
    isDark: false,
  );

  static AppColorScheme forTheme(AppThemeId id) => switch (id) {
    AppThemeId.obsidianGold     => obsidianGold,
    AppThemeId.midnightSapphire => midnightSapphire,
    AppThemeId.forestDusk       => forestDusk,
    AppThemeId.chalkInk         => chalkInk,
    AppThemeId.roseQuartz       => roseQuartz,
  };
}

// ── AppColors – static accessors that read from the active scheme ─────────────
// Widgets import AppColors and call AppColors.bg etc., exactly as before.
// The active scheme is swapped in one place (AppColors._current).
class AppColors {
  AppColors._();

  static AppColorScheme _current = AppThemeSchemes.obsidianGold;

  static void apply(AppColorScheme scheme) { _current = scheme; }

  static Color get bg            => _current.bg;
  static Color get surface       => _current.surface;
  static Color get surfaceEl     => _current.surfaceEl;
  static Color get border        => _current.border;
  static Color get borderStrong  => _current.borderStrong;
  static Color get accent        => _current.accent;
  static Color get accentDim     => _current.accentDim;
  static Color get accentMuted   => _current.accentMuted;
  static Color get textPrimary   => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textMuted     => _current.textMuted;
  static Color get textDim       => _current.textDim;
  static Color get textGhost     => _current.textGhost;
  static Color get incomeGreen    => _current.incomeGreen;
  static Color get incomeGreenDim => _current.incomeGreenDim;
  static Color get expenseRed     => _current.expenseRed;
  static Color get expenseRedDim  => _current.expenseRedDim;
}
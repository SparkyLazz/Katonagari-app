// lib/core/services/preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

/// Supported currencies with their symbols and display names.
class CurrencyInfo {
  final String code;
  final String symbol;
  final String displayName;
  final String locale;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.displayName,
    required this.locale,
  });
}

class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  // ── Keys ──────────────────────────────────────────────
  static const _kLang     = 'language';
  static const _kCurrency = 'currency_code';
  static const _kTheme    = 'app_theme';        // ← NEW

  // ── Supported currencies ──────────────────────────────
  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'IDR', symbol: 'Rp',  displayName: 'Indonesian Rupiah (IDR)', locale: 'id_ID'),
    CurrencyInfo(code: 'USD', symbol: '\$',   displayName: 'US Dollar (USD)',          locale: 'en_US'),
    CurrencyInfo(code: 'MYR', symbol: 'RM',  displayName: 'Malaysian Ringgit (MYR)',  locale: 'ms_MY'),
    CurrencyInfo(code: 'SGD', symbol: 'S\$', displayName: 'Singapore Dollar (SGD)',   locale: 'en_SG'),
    CurrencyInfo(code: 'EUR', symbol: '€',   displayName: 'Euro (EUR)',               locale: 'de_DE'),
    CurrencyInfo(code: 'GBP', symbol: '£',   displayName: 'British Pound (GBP)',      locale: 'en_GB'),
    CurrencyInfo(code: 'JPY', symbol: '¥',   displayName: 'Japanese Yen (JPY)',       locale: 'ja_JP'),
    CurrencyInfo(code: 'SAR', symbol: '﷼',   displayName: 'Saudi Riyal (SAR)',        locale: 'ar_SA'),
  ];

  static CurrencyInfo currencyByCode(String code) =>
      supportedCurrencies.firstWhere(
            (c) => c.code == code,
        orElse: () => supportedCurrencies.first,
      );

  // ── Language ──────────────────────────────────────────
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLang) ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, lang);
  }

  // ── Currency ──────────────────────────────────────────
  Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrency) ?? 'IDR';
  }

  Future<void> setCurrencyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, code);
  }

  // ── Theme ─────────────────────────────────────────────
  Future<AppThemeId> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kTheme);
    if (stored == null) return AppThemeId.obsidianGold;
    return AppThemeId.values.firstWhere(
          (t) => t.storageKey == stored,
      orElse: () => AppThemeId.obsidianGold,
    );
  }

  Future<void> setTheme(AppThemeId theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, theme.storageKey);
  }
}
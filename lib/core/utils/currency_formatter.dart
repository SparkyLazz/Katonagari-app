// lib/core/utils/currency_formatter.dart — REPLACE entire file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:katonagari/core/providers/providers.dart';
import 'package:katonagari/core/services/preferences_service.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  // ── Dynamic (use these everywhere going forward) ──────────────────────────

  static NumberFormat _fmt(String locale) => NumberFormat('#,###', locale);

  /// "Rp 6.500.000" | "$6,500" | "RM 6,500"
  static String formatWith(double amount, CurrencyInfo info) =>
      '${info.symbol} ${_fmt(info.locale).format(amount.abs())}';

  /// Raw number only: "6.500.000" | "6,500"
  static String formatRawWith(double amount, CurrencyInfo info) =>
      _fmt(info.locale).format(amount.abs());

  /// "+Rp 6.500.000" | "−$6,500"
  static String formatSignedWith(double amount, CurrencyInfo info) {
    final sign = amount >= 0 ? '+' : '−';
    return '$sign${info.symbol} ${_fmt(info.locale).format(amount.abs())}';
  }

  /// Short form: IDR → "Rp 6.5jt" / "Rp 500K" ; others → "$6.5M" / "$500K"
  static String formatShortWith(double amount, CurrencyInfo info) {
    final abs = amount.abs();
    if (info.code == 'IDR') {
      if (abs >= 1000000) return '${info.symbol} ${(abs / 1000000).toStringAsFixed(1)}jt';
      if (abs >= 1000)    return '${info.symbol} ${(abs / 1000).round()}K';
      return '${info.symbol} ${abs.round()}';
    } else {
      if (abs >= 1000000) return '${info.symbol}${(abs / 1000000).toStringAsFixed(1)}M';
      if (abs >= 1000)    return '${info.symbol}${(abs / 1000).toStringAsFixed(1)}K';
      return '${info.symbol}${abs.round()}';
    }
  }

  // ── Legacy IDR-only — kept so existing call-sites don't break ────────────
  static final _fmtIDR = NumberFormat('#,###', 'id_ID');

  static String format(double amount) =>
      'Rp ${_fmtIDR.format(amount.abs())}';

  static String formatRaw(double amount) =>
      _fmtIDR.format(amount.abs());

  static String formatSigned(double amount) {
    final sign = amount >= 0 ? '+' : '−';
    return '$sign Rp ${_fmtIDR.format(amount.abs())}';
  }
}

// ── WidgetRef convenience extension ──────────────────────────────────────────
// Inside any ConsumerWidget/ConsumerState:
//   final cur = ref.currency;
//   cur.format(1500000)        →  "Rp 1.500.000"  (or "$1,500" for USD)
//   cur.formatSigned(-50000)   →  "−Rp 50.000"
//   cur.formatShort(1500000)   →  "Rp 1.5jt"
//   cur.symbol                 →  "Rp" | "$" | "RM" …
extension CurrencyRef on WidgetRef {
  CurrencyInfo get currency => watch(currencyProvider);
}

// ── CurrencyInfo shorthand methods ───────────────────────────────────────────
extension CurrencyInfoFormat on CurrencyInfo {
  String format(double amount) =>
      CurrencyFormatter.formatWith(amount, this);

  String formatRaw(double amount) =>
      CurrencyFormatter.formatRawWith(amount, this);

  String formatSigned(double amount) =>
      CurrencyFormatter.formatSignedWith(amount, this);

  String formatShort(double amount) =>
      CurrencyFormatter.formatShortWith(amount, this);
}
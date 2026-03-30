import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── DM Serif Display — headings & amounts ──
  static TextStyle screenTitle = GoogleFonts.dmSerifDisplay(
    fontSize: 24, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, letterSpacing: 0.01 * 24,
  );

  static TextStyle sectionHeading = GoogleFonts.dmSerifDisplay(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, letterSpacing: 0.01 * 16,
  );

  static TextStyle heroAmount = GoogleFonts.dmSerifDisplay(
    fontSize: 42, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, letterSpacing: -0.01 * 42,
  );

  static TextStyle cardTitle = GoogleFonts.dmSerifDisplay(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, letterSpacing: 0.01 * 15,
  );

  // ── Plus Jakarta Sans — body & labels ──
  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.plusJakartaSans(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle label = GoogleFonts.plusJakartaSans(
    fontSize: 11, fontWeight: FontWeight.w600,
    color: AppColors.textMuted, letterSpacing: 0.04 * 11,
  );

  static TextStyle labelCaps = GoogleFonts.plusJakartaSans(
    fontSize: 10, fontWeight: FontWeight.w600,
    color: AppColors.textMuted, letterSpacing: 0.04 * 10,
  );

  static TextStyle buttonText = GoogleFonts.plusJakartaSans(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, letterSpacing: 0.01 * 14,
  );

  static TextStyle navLabel = GoogleFonts.plusJakartaSans(
    fontSize: 10, fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  // ── DM Mono — numeric data only ──
  static TextStyle amountPill = GoogleFonts.dmMono(
    fontSize: 12, fontWeight: FontWeight.w400,
    letterSpacing: 0.02 * 12,
  );

  static TextStyle txAmount = GoogleFonts.dmMono(
    fontSize: 13, fontWeight: FontWeight.w400,
  );

  static TextStyle txAmountLarge = GoogleFonts.dmMono(
    fontSize: 15, fontWeight: FontWeight.w500,
  );
}
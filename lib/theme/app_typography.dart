import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 남구이야기 앱의 타이포그래피
/// Google Fonts (Noto Sans KR) 사용
class AppTypography {
  AppTypography._();

  // Base TextTheme using Noto Sans KR
  static TextTheme get textTheme => GoogleFonts.notoSansKrTextTheme();

  // Headings
  static TextStyle get h1 => GoogleFonts.notoSansKr(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.notoSansKr(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => GoogleFonts.notoSansKr(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get h4 => GoogleFonts.notoSansKr(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get h5 => GoogleFonts.notoSansKr(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  // Body Text
  static TextStyle get bodyLarge => GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  // Labels & Buttons
  static TextStyle get labelLarge => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelSmall => GoogleFonts.notoSansKr(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  // Button Text
  static TextStyle get buttonLarge => GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get buttonMedium => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get buttonSmall => GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
      );

  // Caption & Overline
  static TextStyle get caption => GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  static TextStyle get overline => GoogleFonts.notoSansKr(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.0,
        color: AppColors.textSecondary,
      );
}


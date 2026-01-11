import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 남구이야기 앱의 타이포그래피
class AppTypography {
  AppTypography._();

  static const List<String> _fontFallback = [
    // Android often has Noto Sans KR, macOS has Apple SD Gothic Neo
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'Helvetica Neue',
    'Arial',
  ];

  static TextTheme get textTheme => const TextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );

  // Headings
  static TextStyle get h1 => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get h2 => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get h3 => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get h4 => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get h5 => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  // Body Text
  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textSecondary,
        fontFamilyFallback: _fontFallback,
      );

  // Labels & Buttons
  static TextStyle get labelLarge => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get labelMedium => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get labelSmall => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textSecondary,
        fontFamilyFallback: _fontFallback,
      );

  // Button Text
  static TextStyle get buttonLarge => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get buttonMedium => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get buttonSmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.textOnPrimary,
        fontFamilyFallback: _fontFallback,
      );

  // Caption & Overline
  static TextStyle get caption => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.4,
        color: AppColors.textSecondary,
        fontFamilyFallback: _fontFallback,
      );

  static TextStyle get overline => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.0,
        color: AppColors.textSecondary,
        fontFamilyFallback: _fontFallback,
      );
}


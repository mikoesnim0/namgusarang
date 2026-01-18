import 'package:flutter/material.dart';

/// Walker홀릭 앱의 컬러 팔레트
/// Brand (from Figma): Teal (#10C4AE) + Sky (#69C2FF) with clean whites.
class AppColors {
  AppColors._();

  // Brand
  static const Color brandTeal = Color(0xFF10C4AE);
  static const Color brandSky = Color(0xFF69C2FF);

  // 3rd party (Kakao login button spec)
  static const Color kakaoYellow = Color(0xFFFEE500);
  // Black 85% opacity (Kakao label spec)
  static const Color kakaoLabel = Color(0xD9000000);

  // Primary Colors (teal scale)
  static const Color primary50 = Color(0xFFE6FAF7);
  static const Color primary100 = Color(0xFFC7F2EC);
  static const Color primary200 = Color(0xFF9BE6DD);
  static const Color primary300 = Color(0xFF63D6CB);
  static const Color primary400 = Color(0xFF2CCCBD);
  static const Color primary500 = brandTeal; // 메인
  static const Color primary600 = Color(0xFF0FAF9C);
  static const Color primary700 = Color(0xFF0B8B7B);
  static const Color primary800 = Color(0xFF07685B);
  static const Color primary900 = Color(0xFF054E44);

  // Secondary Colors (sky scale)
  static const Color secondary50 = Color(0xFFEAF7FF);
  static const Color secondary100 = Color(0xFFD3EFFF);
  static const Color secondary200 = Color(0xFFB1E3FF);
  static const Color secondary300 = Color(0xFF86D4FF);
  static const Color secondary400 = Color(0xFF5FC9FF);
  static const Color secondary500 = brandSky;
  static const Color secondary600 = Color(0xFF4AAEE6);
  static const Color secondary700 = Color(0xFF388BC0);
  static const Color secondary800 = Color(0xFF296999);
  static const Color secondary900 = Color(0xFF1E5278);

  // Accent Colors (강조 색상)
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentPink = Color(0xFFE91E63);
  static const Color accentOrange = Color(0xFFFF9800);

  // Semantic Colors (의미론적 색상)
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Grayscale
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);

  // Background & Surface
  static const Color background = Color(0xFFFDFEFE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F8F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Border & Divider
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Overlay & Shadow
  static const Color overlay = Color(0x66000000);
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);
}

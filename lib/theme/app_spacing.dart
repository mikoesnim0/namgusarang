/// 남구이야기 앱의 간격(Spacing) 시스템
/// 8px 기반 스케일 사용
class AppSpacing {
  AppSpacing._();

  // Base unit (8px)
  static const double base = 8.0;

  // Spacing Scale
  static const double xs = base * 0.5; // 4px
  static const double sm = base * 1.0; // 8px
  static const double md = base * 2.0; // 16px
  static const double lg = base * 3.0; // 24px
  static const double xl = base * 4.0; // 32px
  static const double xxl = base * 6.0; // 48px
  static const double xxxl = base * 8.0; // 64px

  // Padding Presets
  static const double paddingXS = xs;
  static const double paddingSM = sm;
  static const double paddingMD = md;
  static const double paddingLG = lg;
  static const double paddingXL = xl;
  static const double paddingXXL = xxl;

  // Margin Presets
  static const double marginXS = xs;
  static const double marginSM = sm;
  static const double marginMD = md;
  static const double marginLG = lg;
  static const double marginXL = xl;

  // Border Radius
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 9999.0;

  // Common UI Element Heights
  static const double buttonHeightSM = 36.0;
  static const double buttonHeightMD = 44.0;
  static const double buttonHeightLG = 56.0;

  static const double inputHeight = 48.0;
  static const double iconSizeSM = 16.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 32.0;
  static const double iconSizeXL = 48.0;

  // Layout Spacing
  static const double screenPaddingHorizontal = md;
  static const double screenPaddingVertical = md;
  static const double sectionSpacing = xl;
  static const double cardSpacing = md;
  static const double listItemSpacing = sm;
}


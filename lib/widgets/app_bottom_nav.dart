import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../features/coupons/coupons_provider.dart';

/// Custom bottom navigation that matches the designer mock:
/// - Light background + white "dock" PNG with center notch
/// - 3 tabs: Home / Coupons (center) / Friends
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newCoupons = ref.watch(newCouponsCountProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final screenW = MediaQuery.sizeOf(context).width;
    final scale = screenW / 1080.0;

    // Use the actual dock PNG ratio so it looks identical across devices.
    // nav_bar_bg.png = 1091x241
    const dockW = 1091.0;
    const dockH = 241.0;
    final dockHeight = (screenW * (dockH / dockW)).clamp(88.0, 260.0);

    // Designer-provided sizes are based on 1080px-wide screens.
    final homeIconW = (67.0 * scale).clamp(22.0, 40.0);
    final friendsIconW = (85.0 * scale).clamp(26.0, 48.0);
    final couponIconW = (104.0 * scale).clamp(34.0, 66.0);

    // Coupon circle diameter (designer mock): 177px on 1080px-wide screens.
    final couponCircle = (177.0 * scale).clamp(60.0, 140.0);

    // Extra room above the dock so the "bump" never gets clipped.
    // Keep this small so the nav doesn't eat too much vertical space.
    final bumpExtra = (44.0 * scale).clamp(12.0, 70.0);
    final totalHeight = dockHeight + bottomInset + bumpExtra;

    // Vertical placement tuned to match the designer mock.
    final sideBottom = bottomInset + dockHeight * 0.18;
    // Lower the coupon circle so it sits closer to the dock like the designer mock.
    // (Requested: +5px lower from current)
    final centerBottom =
        bottomInset + dockHeight - couponCircle * 0.95 - (28.0 * scale);

    final labelFontSize = (27.0 * scale).clamp(11.0, 16.0);
    final centerLabelFontSize = (labelFontSize * 1.06).clamp(11.0, 17.0);
    final centerIconOffsetY = -(20.0 * scale);
    final centerLabelOffsetUp = 5.0 * scale;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background should cover the full bottom inset (gesture bar) too.
          // Designer mock: the area around the dock is white (FFFFFF).
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          Positioned(
            // The PNG has extra transparent margins; bleed slightly so the dock
            // visually reaches the screen edges like the designer mock.
            left: -(16.0 * scale),
            right: -(16.0 * scale),
            // Keep the dock above the OS home indicator area.
            bottom: bottomInset,
            child: SizedBox(
              height: dockHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Base fill: ensures "inside" stays white even if PNG has transparency.
                  Positioned.fill(
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minHeight: dockHeight,
                      maxHeight: dockHeight + 90,
                      child: SizedBox(
                        height: dockHeight + (couponCircle * 0.52),
                        child: CustomPaint(
                          painter: _DockBasePainter(
                            color: Colors.white,
                            radius: dockHeight * 0.18,
                            notchRadius: couponCircle * 0.52,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // PNG overlay (border/shadow)
                  Positioned.fill(
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minHeight: dockHeight,
                      maxHeight: dockHeight + 60,
                      child: Image.asset(
                        'assets/images/nav/nav_bar_bg.png',
                        fit: BoxFit.fitWidth,
                        height: dockHeight + 40,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (context, error, stackTrace) {
                          return SizedBox(height: dockHeight);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Side icons (slightly above the bottom inset)
          Positioned(
            left: 0,
            right: 0,
            bottom: sideBottom,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _IconOnlyNavTile(
                    isActive: currentIndex == 0,
                    activeAssetPath: 'assets/icons/nav/home_on.png',
                    inactiveAssetPath: 'assets/icons/nav/home_off.png',
                    label: '홈',
                    onTap: () => onTap(0),
                    iconWidth: homeIconW,
                    labelFontSize: labelFontSize,
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                Expanded(
                  child: _IconOnlyNavTile(
                    isActive: currentIndex == 2,
                    activeAssetPath: 'assets/icons/nav/friends_on.png',
                    inactiveAssetPath: 'assets/icons/nav/friends_off.png',
                    label: '친구목록',
                    onTap: () => onTap(2),
                    iconWidth: friendsIconW,
                    labelFontSize: labelFontSize,
                  ),
                ),
              ],
            ),
          ),

          // Center button: ensure the raised part is fully visible above the dock.
          Positioned(
            left: 0,
            right: 0,
            bottom: centerBottom,
            child: Center(
              child: _CenterDockButton(
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
                badgeCount: newCoupons,
                size: couponCircle,
                iconWidth: couponIconW,
                labelFontSize: centerLabelFontSize,
                iconOffsetY: centerIconOffsetY,
                labelOffsetUp: centerLabelOffsetUp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconOnlyNavTile extends StatelessWidget {
  const _IconOnlyNavTile({
    required this.isActive,
    required this.activeAssetPath,
    required this.inactiveAssetPath,
    required this.label,
    required this.onTap,
    required this.iconWidth,
    required this.labelFontSize,
  });

  final bool isActive;
  final String activeAssetPath;
  final String inactiveAssetPath;
  final String label;
  final VoidCallback onTap;
  final double iconWidth;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    // Label color stays gray even when active (designer mock).
    final labelColor = AppColors.gray500;
    // Use GestureDetector with HitTestBehavior.opaque so the entire padded
    // area responds to taps, not just the icon/label pixels.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                isActive ? activeAssetPath : inactiveAssetPath,
                width: iconWidth,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(width: iconWidth);
                },
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  fontSize: labelFontSize,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterDockButton extends StatelessWidget {
  const _CenterDockButton({
    required this.isActive,
    required this.onTap,
    required this.badgeCount,
    required this.size,
    required this.iconWidth,
    required this.labelFontSize,
    required this.iconOffsetY,
    required this.labelOffsetUp,
  });

  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;
  final double size;
  final double iconWidth;
  final double labelFontSize;
  final double iconOffsetY;
  final double labelOffsetUp;

  @override
  Widget build(BuildContext context) {
    final asset = isActive
        ? 'assets/icons/nav/coupon_on.png'
        : 'assets/icons/nav/coupon_off.png';
    const labelColor = Color(0xFF888888);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    // Stronger shadow, smaller spread area (designer mock).
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, iconOffsetY),
                    child: Image.asset(
                      asset,
                      width: iconWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(width: iconWidth);
                      },
                    ),
                  ),
                  Positioned(
                    // Keep the icon position visually unchanged; place the label
                    // inside the circle under the icon.
                    bottom: (size * 0.16) + labelOffsetUp,
                    child: Text(
                      '쿠폰함',
                      style: AppTypography.bodyMedium.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w800,
                        fontSize: labelFontSize,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockBasePainter extends CustomPainter {
  _DockBasePainter({
    required this.color,
    required this.radius,
    required this.notchRadius,
  });

  final Color color;
  final double radius;
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = radius.clamp(12.0, 40.0);
    final notchR = notchRadius.clamp(18.0, 96.0);
    final cx = size.width / 2;
    final topY = notchR;

    final path = Path();
    path.moveTo(r, topY);
    // Top edge to notch start
    path.lineTo(cx - notchR, topY);
    // Notch bump up
    final notchRect = Rect.fromCircle(center: Offset(cx, topY), radius: notchR);
    path.arcTo(notchRect, 3.141592653589793, -3.141592653589793, false);
    // Continue top edge
    path.lineTo(size.width - r, topY);
    // Top-right corner
    path.arcToPoint(
      Offset(size.width, topY + r),
      radius: Radius.circular(r),
      clockwise: false,
    );
    // Right side + bottom-right corner
    path.lineTo(size.width, size.height - r);
    path.arcToPoint(
      Offset(size.width - r, size.height),
      radius: Radius.circular(r),
      clockwise: false,
    );
    // Bottom edge + bottom-left corner
    path.lineTo(r, size.height);
    path.arcToPoint(
      Offset(0, size.height - r),
      radius: Radius.circular(r),
      clockwise: false,
    );
    // Left side + top-left corner
    path.lineTo(0, topY + r);
    path.arcToPoint(
      Offset(r, topY),
      radius: Radius.circular(r),
      clockwise: false,
    );
    path.close();

    // Subtle dock shadow so the white surface "floats" over the FAFAFA background.
    // NOTE: Avoid painting a full-shape shadow here, because it can "bleed"
    // above the bump and look like a gray circle intruding into the content.
    // Keep shadows in the PNG and the center button instead.
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DockBasePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.notchRadius != notchRadius;
  }
}

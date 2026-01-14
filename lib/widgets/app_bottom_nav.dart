import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Custom bottom navigation that matches the Figma style:
/// - 4 tabs: Home / Coupons (center raised) / Friends / My
/// - Center "Coupons" button floats above the bar.
///
/// Keep this widget self-contained so contractors can tweak nav visuals
/// without touching routing logic.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItem>[
    _NavItem(
      index: 0,
      label: '홈',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _NavItem(
      index: 1,
      label: '쿠폰함',
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number,
      isCenter: true,
    ),
    _NavItem(
      index: 2,
      label: '친구목록',
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
    ),
    _NavItem(
      index: 3,
      label: '마이',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 78,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Bar background
            Positioned.fill(
              top: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  children: _items.map((it) {
                    if (it.isCenter) {
                      // Reserve space for the floating button + keep label aligned.
                      return Expanded(
                        child: _CenterLabel(
                          label: it.label,
                          isActive: currentIndex == it.index,
                          onTap: () => onTap(it.index),
                        ),
                      );
                    }
                    return Expanded(
                      child: _NavTile(
                        label: it.label,
                        icon: currentIndex == it.index ? it.activeIcon : it.icon,
                        isActive: currentIndex == it.index,
                        onTap: () => onTap(it.index),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Floating center button
            Positioned(
              top: 0,
              child: _CenterButton(
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary500 : AppColors.gray500;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterLabel extends StatelessWidget {
  const _CenterLabel({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary500 : AppColors.gray500;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(height: 26), // reserve icon space (floating button)
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.primary500 : AppColors.surface;
    final fg = isActive ? AppColors.textOnPrimary : AppColors.primary500;
    final shadow = AppColors.shadowMedium;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primary500 : AppColors.border,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.confirmation_number,
            color: fg,
            size: AppSpacing.iconSizeLG,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isCenter = false,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isCenter;
}


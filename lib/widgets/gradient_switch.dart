import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A custom switch that supports a teal->sky gradient when ON.
///
/// Designed to mimic the Figma toggle (cannot be done with Flutter's default Switch).
class GradientSwitch extends StatelessWidget {
  const GradientSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 56,
    this.height = 28,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    final padding = 2.0;
    final knobSize = height - (padding * 2);

    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: value ? Colors.transparent : AppColors.border,
              width: 1,
            ),
            gradient: value
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.brandTeal,
                      AppColors.brandSky,
                    ],
                  )
                : null,
            color: value ? null : AppColors.gray200,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


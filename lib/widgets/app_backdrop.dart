import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sits behind every screen that uses GlassContainer. A flat background has
/// nothing for a frosted-glass panel to actually blur — this adds a few
/// soft, oversized color blobs so the glass chrome reads as glass instead
/// of plain transparency.
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsX.of(context);
    final o = colors.dark ? 0.20 : 0.13;

    return Container(
      color: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: -100, left: -80, child: _blob(AppColors.primary.withValues(alpha: o), 260)),
          Positioned(top: 140, right: -110, child: _blob(AppColors.accent.withValues(alpha: o * 0.8), 280)),
          Positioned(bottom: -120, left: -60, child: _blob(AppColors.primaryDark.withValues(alpha: o), 240)),
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    );
  }
}

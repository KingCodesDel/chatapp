import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps [child] in a frosted-glass panel: blurred background + a soft
/// translucent tint + a hairline highlight border. Used for the app's
/// signature chrome — nav bars, app bars, the message input — not for
/// general body content (blurring text hurts readability).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.glass)),
    this.padding,
    this.blur = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsX.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: borderRadius,
            border: Border.all(color: colors.glassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

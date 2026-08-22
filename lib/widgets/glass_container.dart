import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Flat rounded card — solid surface color, hairline border, soft shadow.
/// Matches the mockup's card style (no frosted/blur effect). Kept the same
/// name/API as before so every screen using GlassContainer picks up the
/// new flat look automatically.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur; // unused now, kept for call-site compatibility

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.glass)),
    this.padding,
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsX.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: borderRadius,
        border: Border.all(color: colors.divider, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: colors.dark ? 0.25 : 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

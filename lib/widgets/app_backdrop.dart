import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Plain background behind every screen — matches the mockup's flat
/// off-white/lavender surface (no blurred color blobs).
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsX.of(context);
    return ColoredBox(color: colors.background, child: child);
  }
}

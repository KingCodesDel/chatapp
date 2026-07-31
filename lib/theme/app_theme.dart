import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colors — stay the same across light/dark, since teal + coral are
/// the app's identity, not something that should shift with the theme.
class AppColors {
  static const primary = Color(0xFF0E7C66);
  static const primaryDark = Color(0xFF0A5C4C);
  static const accent = Color(0xFFFF6B4A);

  // Light-mode surfaces
  static const background = Color(0xFFF7F6F3);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1B1D1F);
  static const textSecondary = Color(0xFF6E7276);
  static const bubbleReceived = Color(0xFFEDEFEE);
  static const divider = Color(0xFFE8E6E1);

  // Dark-mode surfaces
  static const backgroundDark = Color(0xFF14151A);
  static const surfaceDark = Color(0xFF1D1F26);
  static const textPrimaryDark = Color(0xFFF2F2F0);
  static const textSecondaryDark = Color(0xFF9A9DA6);
  static const bubbleReceivedDark = Color(0xFF262832);
  static const dividerDark = Color(0xFF2C2E38);
}

/// Reads the right token for the current brightness. Use this instead of
/// AppColors.background/surface/etc directly wherever a screen needs to
/// support dark mode — e.g. `AppColorsX.of(context).background`.
class AppColorsX {
  final bool dark;
  const AppColorsX(this.dark);

  static AppColorsX of(BuildContext context) => AppColorsX(Theme.of(context).brightness == Brightness.dark);

  Color get background => dark ? AppColors.backgroundDark : AppColors.background;
  Color get surface => dark ? AppColors.surfaceDark : AppColors.surface;
  Color get textPrimary => dark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get textSecondary => dark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get bubbleReceived => dark ? AppColors.bubbleReceivedDark : AppColors.bubbleReceived;
  Color get divider => dark ? AppColors.dividerDark : AppColors.divider;
  Color get glassTint => dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.55);
  Color get glassBorder => dark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.6);
}

class AppSpacing {
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

class AppRadius {
  static const field = 16.0;
  static const card = 18.0;
  static const bubble = 20.0;
  static const bubbleTail = 4.0;
  static const glass = 24.0;
}

class AppTheme {
  static ThemeData _build({required bool dark}) {
    final base = ThemeData(useMaterial3: true, brightness: dark ? Brightness.dark : Brightness.light);
    final bg = dark ? AppColors.backgroundDark : AppColors.background;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final textPrimary = dark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final divider = dark ? AppColors.dividerDark : AppColors.divider;

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2),
      headlineSmall: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: GoogleFonts.sora(fontSize: 15.5, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 15.5, color: textPrimary, height: 1.4),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: textPrimary, height: 1.4),
      bodySmall: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: surface,
        error: const Color(0xFFD64545),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.field), borderSide: BorderSide(color: divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.field), borderSide: BorderSide(color: divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.field), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.7)),
        helperStyle: GoogleFonts.inter(color: textSecondary, fontSize: 11.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
          textStyle: GoogleFonts.sora(fontSize: 15.5, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
      ),
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
    );
  }

  static ThemeData get light => _build(dark: false);
  static ThemeData get dark => _build(dark: true);
}

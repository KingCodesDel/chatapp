import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colors — matched to the ChatVibe UI mockup: a violet/purple
/// identity (buttons, badges, gradients), flat white/lavender surfaces
/// (no glass/blur), and light-lavender outgoing chat bubbles.
class AppColors {
  static const primary = Color(0xFF7C6AE8);
  static const primaryDark = Color(0xFF5B3FD1);
  static const accent = Color(0xFFEC4899);

  // Splash / hero gradient (violet -> deep purple), from the mockup's first screen.
  static const splashTop = Color(0xFF8E7CF0);
  static const splashBottom = Color(0xFF3B2280);

  // Light-mode surfaces
  static const background = Color(0xFFF7F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1B1730);
  static const textSecondary = Color(0xFF8A87A3);
  static const bubbleReceived = Color(0xFFFFFFFF);
  static const bubbleOutgoing = Color(0xFFDCD4FB);
  static const divider = Color(0xFFEDEBF7);
  static const inputFill = Color(0xFFF2F1FA);

  // Dark-mode surfaces
  static const backgroundDark = Color(0xFF14121F);
  static const surfaceDark = Color(0xFF1E1B2E);
  static const textPrimaryDark = Color(0xFFF2F1FA);
  static const textSecondaryDark = Color(0xFF9A96B5);
  static const bubbleReceivedDark = Color(0xFF29253D);
  static const bubbleOutgoingDark = Color(0xFF4A3F8C);
  static const dividerDark = Color(0xFF2C2740);
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
  Color get bubbleOutgoing => dark ? AppColors.bubbleOutgoingDark : AppColors.bubbleOutgoing;
  Color get divider => dark ? AppColors.dividerDark : AppColors.divider;
  // Kept for any screen still referencing the old glass tokens — now flat, not translucent.
  Color get glassTint => surface;
  Color get glassBorder => divider;
}

class AppSpacing {
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

class AppRadius {
  static const field = 14.0;
  static const card = 18.0;
  static const bubble = 18.0;
  static const bubbleTail = 4.0;
  static const glass = 24.0; // now used as the flat card corner radius
}

/// Pill button with the mockup's violet gradient + soft shadow. Used on
/// Login/Register/Sign Up and anywhere the mockup shows a solid gradient CTA.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.height = 54, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF8B77F5), Color(0xFF6A4FE0)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(AppRadius.field),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.field),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

class AppTheme {
  static ThemeData _build({required bool dark}) {
    final base = ThemeData(useMaterial3: true, brightness: dark ? Brightness.dark : Brightness.light);
    final bg = dark ? AppColors.backgroundDark : AppColors.background;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final textPrimary = dark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final divider = dark ? AppColors.dividerDark : AppColors.divider;

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2),
      headlineSmall: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.poppins(fontSize: 15, color: textPrimary, height: 1.4),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, color: textPrimary, height: 1.4),
      bodySmall: GoogleFonts.poppins(fontSize: 12.5, color: textSecondary),
      labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: surface,
        error: const Color(0xFFE85C5C),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? surface : AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.field), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.field), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.field), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: textSecondary.withValues(alpha: 0.8)),
        helperStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 11.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
          textStyle: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primary : divider),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
    );
  }

  static ThemeData get light => _build(dark: false);
  static ThemeData get dark => _build(dark: true);
}

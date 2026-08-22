import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown briefly while Firebase resolves the signed-in/out auth state.
/// Matches the mockup's first screen: violet-to-purple gradient, the
/// ChatVibe mark, wordmark + tagline, and a loading spinner.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.splashTop, AppColors.primaryDark, AppColors.splashBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.4),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 46),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('ChatVibe', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Connect • Share • Be Happy', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
              const Spacer(flex: 3),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

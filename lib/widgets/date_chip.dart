import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The little centered pill ("Today", "Yesterday", "Monday", "12 Mar 2026")
/// shown between groups of messages.
class DateChip extends StatelessWidget {
  final String label;
  const DateChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

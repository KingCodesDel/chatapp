import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Appearance', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: Theme.of(context).dividerColor)),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.instance.mode,
              builder: (context, mode, _) {
                return SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  title: const Text('Dark mode'),
                  subtitle: const Text('Switch between light and dark theme'),
                  secondary: Icon(mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary),
                  value: mode == ThemeMode.dark,
                  onChanged: (value) => ThemeController.instance.setDark(value),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Account', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: Theme.of(context).dividerColor)),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFD64545)),
              title: const Text('Log out'),
              onTap: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

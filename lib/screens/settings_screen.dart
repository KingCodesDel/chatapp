import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import 'archived_chats_screen.dart';
import 'starred_messages_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firestoreService = FirestoreService();
    final myUid = AuthService().currentUser!.uid;

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
          Text('Chats', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: Theme.of(context).dividerColor)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.archive_outlined, color: AppColors.primary),
                  title: const Text('Archived chats'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedChatsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.star_outline_rounded, color: Colors.amber.shade700),
                  title: const Text('Starred messages'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StarredMessagesScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Privacy', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: Theme.of(context).dividerColor)),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: firestoreService.userStream(myUid),
              builder: (context, snap) {
                final data = snap.data?.data();
                final showLastSeen = data?['showLastSeen'] ?? true;
                final showReadReceipts = data?['showReadReceipts'] ?? true;
                return Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text('Show last seen & online status'),
                      subtitle: const Text('If off, you also won\'t see it for others'),
                      value: showLastSeen,
                      onChanged: (v) => firestoreService.updatePrivacySettings(uid: myUid, showLastSeen: v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text('Send read receipts'),
                      subtitle: const Text('If off, others won\'t see the double-check when you read their messages'),
                      value: showReadReceipts,
                      onChanged: (v) => firestoreService.updatePrivacySettings(uid: myUid, showReadReceipts: v),
                    ),
                  ],
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

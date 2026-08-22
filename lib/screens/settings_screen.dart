import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import 'archived_chats_screen.dart';
import 'starred_messages_screen.dart';
import 'blocked_users_screen.dart';
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
        children: [
          const SizedBox(height: AppSpacing.xs),
          _sectionLabel(context, 'General'),
          _row(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications & Sounds',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings aren\'t set up yet'))),
          ),
          const Divider(height: 1),
          _sectionLabel(context, 'Appearance'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) {
              return _row(
                context,
                icon: mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Dark Mode',
                trailing: Switch(activeThumbColor: AppColors.primary, value: mode == ThemeMode.dark, onChanged: (v) => ThemeController.instance.setDark(v)),
              );
            },
          ),
          const Divider(height: 1),
          _sectionLabel(context, 'Chats'),
          _row(
            context,
            icon: Icons.archive_outlined,
            title: 'Archived chats',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedChatsScreen())),
          ),
          _row(
            context,
            icon: Icons.star_outline_rounded,
            iconColor: Colors.amber.shade700,
            title: 'Starred messages',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StarredMessagesScreen())),
          ),
          const Divider(height: 1),
          _sectionLabel(context, 'Privacy & Security'),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestoreService.userStream(myUid),
            builder: (context, snap) {
              final data = snap.data?.data();
              final showLastSeen = data?['showLastSeen'] ?? true;
              final showReadReceipts = data?['showReadReceipts'] ?? true;
              return Column(
                children: [
                  _row(
                    context,
                    icon: Icons.visibility_outlined,
                    title: 'Show last seen & online status',
                    subtitle: 'If off, you also won\'t see it for others',
                    trailing: Switch(activeThumbColor: AppColors.primary, value: showLastSeen, onChanged: (v) => firestoreService.updatePrivacySettings(uid: myUid, showLastSeen: v)),
                  ),
                  _row(
                    context,
                    icon: Icons.done_all_rounded,
                    title: 'Send read receipts',
                    subtitle: 'If off, others won\'t see your double-checks',
                    trailing: Switch(activeThumbColor: AppColors.primary, value: showReadReceipts, onChanged: (v) => firestoreService.updatePrivacySettings(uid: myUid, showReadReceipts: v)),
                  ),
                ],
              );
            },
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestoreService.blockedUsersStream(myUid),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _row(
                context,
                icon: Icons.block_rounded,
                iconColor: const Color(0xFFD64545),
                title: 'Blocked users',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count > 0) Text('$count', style: textTheme.bodyMedium?.copyWith(color: AppColorsX.of(context).textSecondary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
              );
            },
          ),
          const Divider(height: 1),
          _row(
            context,
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFFD64545),
            title: 'Report a problem',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporting isn\'t set up yet'))),
          ),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          _row(
            context,
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFD64545),
            title: 'Log out',
            titleColor: const Color(0xFFD64545),
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text('ChatVibe v2.0.1', style: textTheme.bodySmall?.copyWith(color: AppColorsX.of(context).textSecondary)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? iconColor,
    Color? titleColor,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (iconColor ?? AppColors.primary).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11.5)) : null,
      trailing: trailing,
    );
  }
}

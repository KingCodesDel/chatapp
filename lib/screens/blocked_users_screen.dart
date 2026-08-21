import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final myUid = AuthService().currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestoreService.blockedUsersStream(myUid),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text("You haven't blocked anyone", style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
            itemBuilder: (context, index) {
              final blockedUid = docs[index].id;
              return FutureBuilder<AppUser?>(
                future: firestoreService.getUser(blockedUid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || userSnap.data == null) return const SizedBox(height: 72);
                  final user = userSnap.data!;
                  return ListTile(
                    leading: UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 48),
                    title: Text(user.username, style: textTheme.titleMedium),
                    trailing: TextButton(
                      onPressed: () => firestoreService.unblockUser(myUid, blockedUid),
                      child: const Text('Unblock'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

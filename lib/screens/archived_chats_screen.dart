import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final myUid = authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Archived chats')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestoreService.chatsStream(myUid),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final archived = snap.data!.docs.where((d) => (d.data()['archived'] as Map<String, dynamic>?)?[myUid] == true).toList();

          if (archived.isEmpty) {
            return Center(child: Text('No archived chats', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)));
          }

          return ListView.separated(
            itemCount: archived.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
            itemBuilder: (context, index) {
              final doc = archived[index];
              final chat = doc.data();
              final isGroup = chat['isGroup'] == true;

              if (isGroup) {
                final name = chat['groupName'] as String? ?? 'Group';
                final photo = chat['groupPhotoUrl'] as String?;
                return _row(context, name, photo, chat['lastMessage'] ?? '', () async {
                  await firestoreService.setArchived(doc.id, myUid, false);
                  if (context.mounted) {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ChatScreen(otherUid: doc.id, displayName: name, isGroup: true, groupPhotoUrl: photo)));
                  }
                });
              }

              final participants = List<String>.from(chat['participants']);
              final otherUid = participants.firstWhere((id) => id != myUid);
              return FutureBuilder<AppUser?>(
                future: firestoreService.getUser(otherUid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || userSnap.data == null) return const SizedBox.shrink();
                  final user = userSnap.data!;
                  return _row(context, user.username, user.photoUrl, chat['lastMessage'] ?? '', () async {
                    await firestoreService.setArchived(doc.id, myUid, false);
                    if (context.mounted) {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatScreen(otherUid: otherUid, displayName: user.username, otherPhotoUrl: user.photoUrl)));
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String name, String? photo, String lastMessage, VoidCallback onTap) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: UserAvatar(label: name, photoUrl: photo, size: 48),
      title: Text(name, style: textTheme.titleMedium),
      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.unarchive_outlined, color: AppColors.primary),
      onTap: onTap,
    );
  }
}

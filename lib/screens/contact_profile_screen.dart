import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'image_viewer_screen.dart';

class ContactProfileScreen extends StatefulWidget {
  final String otherUid;
  final String currentDisplayName;

  const ContactProfileScreen({super.key, required this.otherUid, required this.currentDisplayName});

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  late final TextEditingController _nicknameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.currentDisplayName);
  }

  Future<void> _saveNickname() async {
    setState(() => _saving = true);
    try {
      await _firestoreService.addOrUpdateContact(
        myUid: _authService.currentUser!.uid,
        contactUid: widget.otherUid,
        nickname: _nicknameCtrl.text,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Delete this chat?'),
        content: const Text('This removes the conversation from your chat list. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirm != true) return;
    final myUid = _authService.currentUser!.uid;
    final chatId = _firestoreService.buildChatId(myUid, widget.otherUid);
    await _firestoreService.deleteChat(chatId);
    if (mounted) {
      Navigator.of(context).pop(); // close profile screen
      Navigator.of(context).pop(); // close chat screen, back to chat list
    }
  }

  Future<void> _toggleBlock(bool currentlyBlocked) async {
    final myUid = _authService.currentUser!.uid;
    if (currentlyBlocked) {
      await _firestoreService.unblockUser(myUid, widget.otherUid);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Text('Block this person?'),
          content: const Text("You won't be able to message each other."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('BLOCK')),
          ],
        ),
      );
      if (confirm != true) return;
      await _firestoreService.blockUser(myUid, widget.otherUid);
    }
  }

  Future<void> _reportUser() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Report this person'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'What happened?'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, reasonCtrl.text), child: const Text('SUBMIT')),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _firestoreService.reportUser(reporterUid: _authService.currentUser!.uid, reportedUid: widget.otherUid, reason: reason.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.userStream(widget.otherUid),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final user = AppUser.fromMap(snap.data!.data()!);

          return StreamBuilder<bool>(
            stream: _firestoreService.isBlockedByMeStream(myUid, widget.otherUid),
            builder: (context, blockSnap) {
              final blocked = blockSnap.data ?? false;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: (user.photoUrl.isEmpty)
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: user.photoUrl))),
                      child: UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 140),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(child: Text('@${user.username}', style: textTheme.titleLarge)),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Center(child: Text(user.bio, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Align(alignment: Alignment.centerLeft, child: Text('Nickname (only you see this)', style: textTheme.titleMedium)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _nicknameCtrl, decoration: const InputDecoration(hintText: 'Rename this contact'))),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: _saving
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                        onPressed: _saving ? null : _saveNickname,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(blocked ? Icons.person_add_alt_1_rounded : Icons.block_rounded, color: blocked ? AppColors.primary : Colors.red),
                    title: Text(blocked ? 'Unblock' : 'Block', style: TextStyle(color: blocked ? AppColors.primary : Colors.red)),
                    onTap: () => _toggleBlock(blocked),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined, color: Colors.red),
                    title: const Text('Report', style: TextStyle(color: Colors.red)),
                    onTap: _reportUser,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: const Text('Delete chat', style: TextStyle(color: Colors.red)),
                    onTap: _deleteChat,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

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
  bool _myShowLastSeen = true;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.currentDisplayName);
    _loadMyPrivacyPref();
  }

  Future<void> _loadMyPrivacyPref() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_authService.currentUser!.uid).get();
    if (mounted) setState(() => _myShowLastSeen = doc.data()?['showLastSeen'] != false);
  }

  String _presenceText(Map<String, dynamic>? data) {
    if (data?['online'] == true) return 'Online';
    final lastSeen = data?['lastSeen'] as Timestamp?;
    if (lastSeen == null) return '';
    final diff = DateTime.now().difference(lastSeen.toDate());
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
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

  Future<void> _setDisappearing(String chatId, int? currentSeconds) async {
    final options = {'Off': null, '24 hours': 86400, '7 days': 604800};
    final choice = await showDialog<int?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Disappearing messages'),
        children: options.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e.value),
                  child: Row(
                    children: [
                      if (currentSeconds == e.value) const Icon(Icons.check, size: 18, color: AppColors.primary),
                      if (currentSeconds == e.value) const SizedBox(width: 8),
                      Text(e.key),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (choice == currentSeconds) return;
    await _firestoreService.setDisappearingSeconds(chatId, choice);
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
              final chatId = _firestoreService.buildChatId(myUid, widget.otherUid);

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.chatDocStream(chatId),
                builder: (context, chatSnap) {
                  final muted = (chatSnap.data?.data()?['muted'] as Map<String, dynamic>?)?[myUid] == true;

                  return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: (user.photoUrl.isEmpty)
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrls: [user.photoUrl]))),
                      child: UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 140),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(child: Text('@${user.username}', style: textTheme.titleLarge)),
                  if (_myShowLastSeen && (snap.data!.data()?['showLastSeen'] != false))
                    Center(child: Text(_presenceText(snap.data!.data()), style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))),
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
                    leading: Icon(muted ? Icons.notifications_off_rounded : Icons.notifications_none_rounded, color: AppColors.primary),
                    title: Text(muted ? 'Unmute notifications' : 'Mute notifications'),
                    onTap: () => _firestoreService.setMuted(chatId, myUid, !muted),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                    title: const Text('Disappearing messages'),
                    subtitle: Text(() {
                      final s = chatSnap.data?.data()?['disappearingSeconds'] as int?;
                      if (s == null) return 'Off';
                      return s == 86400 ? '24 hours' : '7 days';
                    }()),
                    onTap: () => _setDisappearing(chatId, chatSnap.data?.data()?['disappearingSeconds'] as int?),
                  ),
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
          );
        },
      ),
    );
  }
}

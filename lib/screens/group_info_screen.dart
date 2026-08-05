import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _storageService = StorageService();
  final _picker = ImagePicker();
  bool _uploadingPhoto = false;

  Future<void> _changeGroupPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _storageService.uploadGroupPhoto(widget.chatId, File(picked.path));
      await _firestoreService.updateGroupPhoto(widget.chatId, url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _renameGroup(String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Rename group'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Group name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('SAVE')),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    await _firestoreService.renameGroup(widget.chatId, newName);
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Leave group?'),
        content: const Text("You won't receive messages from this group anymore."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('LEAVE')),
        ],
      ),
    );
    if (confirm != true) return;
    await _firestoreService.leaveGroup(widget.chatId, _authService.currentUser!.uid);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _addMembers() async {
    // Reuses the search screen's contact-picking flow by pushing search,
    // then adding whoever the user starts a "chat" with into this group.
    // Simplest reliable version: prompt for username directly.
    final ctrl = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Add member'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Their username')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('ADD')),
        ],
      ),
    );
    if (username == null || username.trim().isEmpty) return;

    final results = await _firestoreService.searchUsersByUsername(username.trim(), _authService.currentUser!.uid);
    final match = results.where((u) => u.username.toLowerCase() == username.trim().toLowerCase()).toList();
    if (match.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No exact match found')));
      return;
    }
    await _firestoreService.addGroupMembers(widget.chatId, [match.first.uid]);
  }

  Future<void> _removeMember(String uid) async {
    await _firestoreService.removeGroupMember(widget.chatId, uid);
  }

  Future<void> _shareInviteLink() async {
    final code = await _firestoreService.createGroupInvite(widget.chatId);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Invite code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this code — anyone who enters it under "Join a group" will be added.'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3, color: AppColors.primary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
            },
            child: const Text('COPY & CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDisappearing(int? currentSeconds) async {
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
    await _firestoreService.setDisappearingSeconds(widget.chatId, choice);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(choice == null
            ? 'Disappearing messages turned off'
            : 'New messages will disappear after ${choice == 86400 ? '24 hours' : '7 days'}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.chatDocStream(widget.chatId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final chat = snapshot.data!.data()!;
          final groupName = chat['groupName'] as String? ?? 'Group';
          final groupPhotoUrl = chat['groupPhotoUrl'] as String?;
          final participants = List<String>.from(chat['participants'] ?? []);
          final admins = List<String>.from(chat['admins'] ?? []);
          final isAdmin = admins.contains(myUid);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Stack(
                  children: [
                    UserAvatar(label: groupName, photoUrl: groupPhotoUrl, size: 96),
                    if (_uploadingPhoto)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4)),
                          child: const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : _changeGroupPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: GestureDetector(
                  onTap: () => _renameGroup(groupName),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(groupName, style: textTheme.headlineSmall),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${participants.length} members', style: textTheme.titleMedium),
                  TextButton.icon(onPressed: _addMembers, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Add')),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ...participants.map((uid) => FutureBuilder<AppUser?>(
                    future: _firestoreService.getUser(uid),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData || userSnap.data == null) return const SizedBox.shrink();
                      final user = userSnap.data!;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 44),
                        title: Text(user.username),
                        subtitle: admins.contains(uid) ? const Text('Admin') : null,
                        trailing: (isAdmin && uid != myUid)
                            ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFD64545)), onPressed: () => _removeMember(uid))
                            : null,
                      );
                    },
                  )),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded, color: AppColors.primary),
                title: const Text('Invite via link'),
                subtitle: const Text('Share a code so someone can join'),
                onTap: _shareInviteLink,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                title: const Text('Disappearing messages'),
                subtitle: Text(chat['disappearingSeconds'] == null
                    ? 'Off'
                    : chat['disappearingSeconds'] == 86400
                        ? '24 hours'
                        : '7 days'),
                onTap: () => _setDisappearing(chat['disappearingSeconds'] as int?),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _leaveGroup,
                icon: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFD64545)),
                label: const Text('Leave group', style: TextStyle(color: Color(0xFFD64545))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD64545)), minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_avatar.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _nameCtrl = TextEditingController();

  final Set<String> _selected = {};
  bool _creating = false;

  Future<void> _create() async {
    if (_selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least 2 people for a group')),
      );
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the group a name')));
      return;
    }

    setState(() => _creating = true);
    try {
      final myUid = _authService.currentUser!.uid;
      final chatId = await _firestoreService.createGroupChat(
        creatorUid: myUid,
        memberUids: _selected.toList(),
        groupName: _nameCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(otherUid: chatId, displayName: _nameCtrl.text.trim(), isGroup: true)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select people from your contacts', style: textTheme.bodySmall),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.contactsStream(myUid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final contacts = snapshot.data!.docs;
                if (contacts.isEmpty) {
                  return Center(
                    child: Text('Message someone first to add them to a group', style: textTheme.bodyMedium),
                  );
                }
                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final data = contacts[index].data();
                    final contactUid = data['contactUid'] as String;
                    final nickname = data['nickname'] as String? ?? contactUid;
                    final selected = _selected.contains(contactUid);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(contactUid);
                        } else {
                          _selected.remove(contactUid);
                        }
                      }),
                      activeColor: AppColors.primary,
                      secondary: GradientAvatar(label: nickname, size: 44),
                      title: Text(nickname, style: textTheme.titleMedium),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _creating ? null : _create,
                  child: _creating
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Create group (${_selected.length} selected)'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

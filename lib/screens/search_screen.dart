import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  List<AppUser> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final myUid = _authService.currentUser!.uid;
    final results = await _firestoreService.searchUsersByUsername(query, myUid);
    setState(() {
      _results = results;
      _loading = false;
      _searched = true;
    });
  }

  Future<void> _startChat(AppUser user) async {
    final myUid = _authService.currentUser!.uid;
    final nicknameCtrl = TextEditingController(text: user.username);

    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('Save ${user.username} as...', style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          controller: nicknameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nickname', helperText: 'Only you see this'),
        ),
        actionsPadding: const EdgeInsets.only(right: AppSpacing.sm, bottom: AppSpacing.xs),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, nicknameCtrl.text),
            child: const Text('Save & chat'),
          ),
        ],
      ),
    );

    if (nickname == null) return;
    final finalNickname = nickname.trim().isEmpty ? user.username : nickname.trim();

    await _firestoreService.addOrUpdateContact(myUid: myUid, contactUid: user.uid, nickname: finalNickname);

    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatScreen(otherUid: user.uid, displayName: finalNickname)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: textTheme.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Search by username...',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.trim().length >= 2) _search(v);
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : (_searched && _results.isEmpty)
              ? Center(
                  child: Text('No users found', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return InkWell(
                      onTap: () => _startChat(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                        child: Row(
                          children: [
                            UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 52),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.username, style: textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(user.email, style: textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

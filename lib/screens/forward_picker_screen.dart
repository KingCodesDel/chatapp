import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/user_avatar.dart';

/// Pick one or more existing chats (people or groups) to forward a message to.
/// Pops with the list of selected chat ids, or null if cancelled.
class ForwardPickerScreen extends StatefulWidget {
  /// Chat the message is coming from - hidden from the list.
  final String? excludeChatId;
  const ForwardPickerScreen({super.key, this.excludeChatId});

  @override
  State<ForwardPickerScreen> createState() => _ForwardPickerScreenState();
}

class _ForwardPickerScreenState extends State<ForwardPickerScreen> {
  final _firestoreService = FirestoreService();
  final _selected = <String>{};
  final _search = TextEditingController();
  late final String _myUid = AuthService().currentUser!.uid;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_selected.isEmpty ? 'Forward to...' : '${_selected.length} selected'),
        ),
        floatingActionButton: _selected.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                onPressed: () => Navigator.pop(context, _selected.toList()),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text('Send', style: TextStyle(color: Colors.white)),
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search chats...', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.chatsStream(_myUid),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  final docs = snap.data!.docs.where((d) => d.id != widget.excludeChatId).toList();
                  if (docs.isEmpty) {
                    return const Center(child: Text('No other chats yet'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: docs.length,
                    itemBuilder: (context, i) => _ChatPickRow(
                      doc: docs[i],
                      myUid: _myUid,
                      query: _search.text.trim().toLowerCase(),
                      selected: _selected.contains(docs[i].id),
                      onToggle: () => setState(() {
                        if (!_selected.remove(docs[i].id)) _selected.add(docs[i].id);
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPickRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String myUid;
  final String query;
  final bool selected;
  final VoidCallback onToggle;

  const _ChatPickRow({required this.doc, required this.myUid, required this.query, required this.selected, required this.onToggle});

  Widget _tile({required String name, String? photoUrl}) {
    if (query.isNotEmpty && !name.toLowerCase().contains(query)) return const SizedBox.shrink();
    return ListTile(
      leading: UserAvatar(label: name, photoUrl: photoUrl, size: 44),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      onTap: onToggle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    if (data['isGroup'] == true) {
      return _tile(name: (data['groupName'] as String?) ?? 'Group', photoUrl: data['groupPhotoUrl'] as String?);
    }
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUid = participants.firstWhere((u) => u != myUid, orElse: () => '');
    if (otherUid.isEmpty) return const SizedBox.shrink();
    return FutureBuilder(
      future: FirestoreService().getUser(otherUid),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const SizedBox.shrink();
        return _tile(name: user.username, photoUrl: user.photoUrl);
      },
    );
  }
}

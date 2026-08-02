import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

const _statusColors = [
  Color(0xFF0E7C66),
  Color(0xFFFF6B4A),
  Color(0xFF5B5FEF),
  Color(0xFFE0A83E),
  Color(0xFF3E8FE0),
  Color(0xFFD64545),
  Color(0xFF14151A),
];

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _storageService = StorageService();
  final _picker = ImagePicker();
  bool _posting = false;

  Future<void> _choosePostType() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.primary),
              title: const Text('Photo status'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields_rounded, color: AppColors.primary),
              title: const Text('Text status'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == 'photo') await _postPhotoStatus();
    if (choice == 'text') await _postTextStatus();
  }

  Future<void> _postPhotoStatus() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _posting = true);
    try {
      final uid = _authService.currentUser!.uid;
      final url = await _storageService.uploadStatusImage(uid, File(picked.path));
      await _firestoreService.postStatus(uid: uid, type: 'image', mediaUrl: url);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post status: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _postTextStatus() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _TextStatusComposeScreen(), fullscreenDialog: true),
    );
    if (result == null) return;
    setState(() => _posting = true);
    try {
      final uid = _authService.currentUser!.uid;
      await _firestoreService.postStatus(uid: uid, type: 'text', text: result['text'], bgColor: result['bgColor']);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.contactsStream(myUid),
        builder: (context, contactsSnap) {
          final contactUids = contactsSnap.data?.docs.map((d) => d.data()['contactUid'] as String).toList() ?? [];
          final relevantUids = {myUid, ...contactUids}.toList();

          return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _firestoreService.getRecentStatuses(relevantUids),
            builder: (context, statusSnap) {
              final allStatuses = statusSnap.data ?? [];
              final myStatuses = allStatuses.where((d) => d.data()['uid'] == myUid).toList()
                ..sort((a, b) => (b.data()['createdAt'] as Timestamp).compareTo(a.data()['createdAt'] as Timestamp));

              final byUid = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
              for (final doc in allStatuses) {
                final uid = doc.data()['uid'] as String;
                if (uid == myUid) continue;
                byUid.putIfAbsent(uid, () => []).add(doc);
              }

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  ListTile(
                    leading: Stack(
                      children: [
                        const UserAvatar(label: 'Me', size: 52),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                            child: _posting
                                ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                    title: Text('My status', style: textTheme.titleMedium),
                    subtitle: Text(myStatuses.isEmpty ? 'Tap to add a status update' : '${myStatuses.length} update(s) · tap to view'),
                    onTap: myStatuses.isEmpty
                        ? (_posting ? null : _choosePostType)
                        : () => _openViewer(context, myStatuses, 'Me', isOwn: true),
                    trailing: myStatuses.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: _posting ? null : _choosePostType),
                  ),
                  if (byUid.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                      child: Text('Recent updates', style: textTheme.bodySmall),
                    ),
                    ...byUid.entries.map((entry) => FutureBuilder<AppUser?>(
                          future: _firestoreService.getUser(entry.key),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || userSnap.data == null) return const SizedBox.shrink();
                            final user = userSnap.data!;
                            final viewed = entry.value.every((d) => (d.data()['viewedBy'] as List?)?.contains(myUid) == true);
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: viewed ? AppColors.divider : AppColors.primary, width: 2)),
                                child: UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 48),
                              ),
                              title: Text(user.username, style: textTheme.titleMedium),
                              subtitle: Text('${entry.value.length} update(s)'),
                              onTap: () => _openViewer(context, entry.value, user.username, isOwn: false),
                            );
                          },
                        )),
                  ],
                  if (byUid.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: Text('No recent updates from your contacts', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openViewer(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> statuses, String name, {required bool isOwn}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _StatusViewer(statuses: statuses, name: name, firestoreService: _firestoreService, myUid: _authService.currentUser!.uid, isOwn: isOwn),
    ));
    if (mounted) setState(() {}); // refresh in case a status was deleted
  }
}

class _TextStatusComposeScreen extends StatefulWidget {
  const _TextStatusComposeScreen();

  @override
  State<_TextStatusComposeScreen> createState() => _TextStatusComposeScreenState();
}

class _TextStatusComposeScreenState extends State<_TextStatusComposeScreen> {
  final _textCtrl = TextEditingController();
  Color _bgColor = _statusColors[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                TextButton(
                  onPressed: _textCtrl.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, {'text': _textCtrl.text.trim(), 'bgColor': _bgColor.toARGB32()}),
                  child: const Text('POST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: TextField(
                    controller: _textCtrl,
                    autofocus: true,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _statusColors.map((c) {
                  final selected = c == _bgColor;
                  return GestureDetector(
                    onTap: () => setState(() => _bgColor = c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: selected ? 34 : 28,
                      height: selected ? 34 : 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: selected ? 3 : 1.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> statuses;
  final String name;
  final FirestoreService firestoreService;
  final String myUid;
  final bool isOwn;

  const _StatusViewer({required this.statuses, required this.name, required this.firestoreService, required this.myUid, required this.isOwn});

  @override
  State<_StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<_StatusViewer> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _statuses;
  int _index = 0;
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    _statuses = List.of(widget.statuses);
    widget.firestoreService.markStatusViewed(_statuses[0].id, widget.myUid);
  }

  void _next() {
    if (_index < _statuses.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Delete this status?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.firestoreService.deleteStatus(_statuses[_index].id);
    if (!mounted) return;
    if (_statuses.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _statuses.removeAt(_index);
      if (_index >= _statuses.length) _index = _statuses.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _statuses.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                widget.firestoreService.markStatusViewed(_statuses[i].id, widget.myUid);
              },
              itemBuilder: (context, i) {
                final data = _statuses[i].data();
                final type = data['type'] as String? ?? 'image';
                return GestureDetector(
                  onTapUp: (details) {
                    final width = MediaQuery.of(context).size.width;
                    if (details.globalPosition.dx < width / 2) {
                      _prev();
                    } else {
                      _next();
                    }
                  },
                  child: type == 'text'
                      ? Container(
                          color: Color(data['bgColor'] as int? ?? 0xFF0E7C66),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            data['text'] as String? ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                          ),
                        )
                      : Center(
                          child: data['mediaUrl'] != null
                              ? Image.network(data['mediaUrl'], fit: BoxFit.contain)
                              : const Icon(Icons.image_not_supported, color: Colors.white54, size: 48),
                        ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  _statuses.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: i <= _index ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 12,
              child: Text(widget.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            Positioned(
              top: 16,
              right: 8,
              child: Row(
                children: [
                  if (widget.isOwn) IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white), onPressed: _delete),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

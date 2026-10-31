import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import 'channel_screen.dart';
import 'discover_screen.dart';
import 'status_compose_screen.dart';
import '../widgets/video_widgets.dart';
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
  State<StatusScreen> createState() => StatusScreenState();
}

class StatusScreenState extends State<StatusScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _storageService = StorageService();
  final _picker = ImagePicker();
  bool _posting = false;

  Future<void> choosePostType() async {
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
              leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              title: const Text('Video status'),
              onTap: () => Navigator.pop(context, 'video'),
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
    if (choice == 'video') await _postVideoStatus();
    if (choice == 'text') await _postTextStatus();
  }

  Future<void> _postPhotoStatus() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final caption = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => StatusComposeScreen(file: file, isVideo: false), fullscreenDialog: true),
    );
    if (caption == null) return;
    setState(() => _posting = true);
    try {
      final uid = _authService.currentUser!.uid;
      final url = await _storageService.uploadStatusImage(uid, file);
      await _firestoreService.postStatus(uid: uid, type: 'image', mediaUrl: url, caption: caption);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post status: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _postVideoStatus() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final sizeMb = (await file.length()) / (1024 * 1024);
    if (sizeMb > 60) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video is ${sizeMb.toStringAsFixed(0)} MB - please choose one under 60 MB')));
      return;
    }
    if (!mounted) return;
    final caption = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => StatusComposeScreen(file: file, isVideo: true), fullscreenDialog: true),
    );
    if (caption == null) return;
    setState(() => _posting = true);
    try {
      final uid = _authService.currentUser!.uid;
      final url = await _storageService.uploadStatusVideo(uid, file);
      await _firestoreService.postStatus(uid: uid, type: 'video', mediaUrl: url, caption: caption);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post video: $e')));
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

    // No own Scaffold/AppBar here — this widget is only ever embedded as the
    // Status/Updates tab inside HomeScreen, which owns the header (title +
    // camera/edit actions) to avoid a duplicated toolbar.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  const ChannelTile(),
                  const DiscoverTiles(),
                  const Divider(height: 1),
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
                    title: Text('My Status', style: textTheme.titleMedium),
                    subtitle: Text(myStatuses.isEmpty ? 'Tap to add status' : '${myStatuses.length} update(s) · tap to view'),
                    onTap: myStatuses.isEmpty
                        ? (_posting ? null : choosePostType)
                        : () => _openViewer(context, myStatuses, 'Me', isOwn: true),
                    trailing: myStatuses.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: _posting ? null : choosePostType),
                  ),
                  if (byUid.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                      child: Text('Recent Updates', style: textTheme.titleMedium),
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
    _markViewed(0);
  }

  void _markViewed(int i) {
    if (widget.isOwn) return;
    final viewedBy = (_statuses[i].data()['viewedBy'] as List?) ?? const [];
    if (viewedBy.contains(widget.myUid)) return;
    widget.firestoreService.markStatusViewed(_statuses[i].id, widget.myUid);
  }

  void _showViewers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (_) => _ViewersSheet(statusId: _statuses[_index].id, ownerUid: widget.myUid, firestoreService: widget.firestoreService),
    );
  }

  void _showComments(String statusId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (_) => _CommentsSheet(
        statusId: statusId,
        myUid: widget.myUid,
        isStatusOwner: widget.isOwn,
        firestoreService: widget.firestoreService,
      ),
    );
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
                _markViewed(i);
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
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            if (data['mediaUrl'] == null)
                              const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 48))
                            else if (type == 'video')
                              StatusVideo(key: ValueKey(_statuses[i].id), url: data['mediaUrl'], onEnded: () { if (i == _index) _next(); })
                            else
                              Center(child: Image.network(data['mediaUrl'], fit: BoxFit.contain)),
                            if (((data['caption'] as String?) ?? '').isNotEmpty)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 78),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                                  ),
                                  child: Text(
                                    data['caption'] as String,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3),
                                  ),
                                ),
                              ),
                          ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Builder(builder: (_) {
                    final postedAt = TimeFormat.fromTs(_statuses[_index].data()['createdAt']);
                    if (postedAt == null) return const SizedBox.shrink();
                    return Text(TimeFormat.dayAndClock(postedAt), style: const TextStyle(color: Colors.white70, fontSize: 11.5));
                  }),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: widget.firestoreService.statusStream(_statuses[_index].id),
                builder: (context, snap) {
                  final d = snap.data?.data() ?? {};
                  final viewedBy = List<String>.from(d['viewedBy'] ?? [])..remove(widget.myUid);
                  final likedBy = List<String>.from(d['likedBy'] ?? []);
                  final liked = likedBy.contains(widget.myUid);
                  final comments = (d['commentCount'] as int?) ?? 0;
                  final statusId = _statuses[_index].id;
                  Widget action(IconData icon, String label, VoidCallback? onTap, {Color color = Colors.white}) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: color, size: 24),
                            if (label.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isOwn) action(Icons.remove_red_eye_outlined, '${viewedBy.length}', _showViewers),
                      action(
                        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        likedBy.isEmpty ? '' : '${likedBy.length}',
                        () => widget.firestoreService.setStatusLike(statusId, widget.myUid, !liked),
                        color: liked ? AppColors.accent : Colors.white,
                      ),
                      action(Icons.chat_bubble_outline_rounded, comments == 0 ? '' : '$comments', () => _showComments(statusId)),
                    ],
                  );
                },
              ),
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

/// "Viewed by" list for one of your own statuses, updating live.
class _ViewersSheet extends StatelessWidget {
  final String statusId;
  final String ownerUid;
  final FirestoreService firestoreService;
  const _ViewersSheet({required this.statusId, required this.ownerUid, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestoreService.statusStream(statusId),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final viewedAt = (data['viewedAt'] as Map?) ?? {};
            final viewers = List<String>.from(data['viewedBy'] ?? [])..remove(ownerUid);
            // Most recent viewers first; people with no recorded time go last.
            viewers.sort((a, b) {
              final ta = viewedAt[a] is Timestamp ? (viewedAt[a] as Timestamp).millisecondsSinceEpoch : 0;
              final tb = viewedAt[b] is Timestamp ? (viewedAt[b] as Timestamp).millisecondsSinceEpoch : 0;
              return tb.compareTo(ta);
            });
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Viewed by ${viewers.length}', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (viewers.isEmpty)
                  const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('No views yet'))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      itemBuilder: (context, i) {
                        final uid = viewers[i];
                        final at = TimeFormat.fromTs(viewedAt[uid]);
                        return FutureBuilder<AppUser?>(
                          future: firestoreService.getUser(uid),
                          builder: (context, userSnap) {
                            final user = userSnap.data;
                            return ListTile(
                              leading: UserAvatar(label: user?.username ?? '?', photoUrl: user?.photoUrl, size: 40),
                              title: Text(user?.username ?? 'Loading...'),
                              subtitle: at == null ? null : Text(TimeFormat.dayAndClock(at)),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Comments on a status. Anyone who can see the status can comment;
/// you can delete your own comments, and the status owner can delete any.
class _CommentsSheet extends StatefulWidget {
  final String statusId;
  final String myUid;
  final bool isStatusOwner;
  final FirestoreService firestoreService;
  const _CommentsSheet({required this.statusId, required this.myUid, required this.isStatusOwner, required this.firestoreService});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final _users = <String, AppUser?>{};
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser(String uid) async {
    if (_users.containsKey(uid)) return;
    _users[uid] = null;
    final u = await widget.firestoreService.getUser(uid);
    if (mounted) setState(() => _users[uid] = u);
  }

  Future<void> _send() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    try {
      await widget.firestoreService.addStatusComment(widget.statusId, widget.myUid, text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not comment: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.firestoreService.statusCommentsStream(widget.statusId),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No comments yet - be the first'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final c = docs[i].data();
                        final uid = c['uid'] as String? ?? '';
                        _loadUser(uid);
                        final user = _users[uid];
                        final at = TimeFormat.fromTs(c['createdAt']);
                        final canDelete = uid == widget.myUid || widget.isStatusOwner;
                        return ListTile(
                          leading: UserAvatar(label: user?.username ?? '?', photoUrl: user?.photoUrl, size: 36),
                          title: Text(user?.username ?? '...', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${c['text'] ?? ''}${at == null ? '' : '\n${TimeFormat.dayAndClock(at)}'}'),
                          isThreeLine: at != null,
                          onLongPress: canDelete ? () => widget.firestoreService.deleteStatusComment(widget.statusId, docs[i].id) : null,
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(hintText: 'Add a comment...', counterText: ''),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.primary), onPressed: _sending ? null : _send),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  Future<void> _postStatus() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _posting = true);
    try {
      final uid = _authService.currentUser!.uid;
      final url = await _storageService.uploadStatusImage(uid, File(picked.path));
      await _firestoreService.postStatus(uid: uid, mediaUrl: url);
      if (mounted) setState(() {}); // refresh the list
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post status: $e')));
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
                        UserAvatar(label: 'Me', size: 52),
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
                        ? _posting
                            ? null
                            : _postStatus
                        : () => _openViewer(context, myStatuses, 'Me'),
                    trailing: myStatuses.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: _posting ? null : _postStatus),
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
                              onTap: () => _openViewer(context, entry.value, user.username),
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

  void _openViewer(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> statuses, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _StatusViewer(statuses: statuses, name: name, firestoreService: _firestoreService, myUid: _authService.currentUser!.uid),
    ));
  }
}

class _StatusViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> statuses;
  final String name;
  final FirestoreService firestoreService;
  final String myUid;

  const _StatusViewer({required this.statuses, required this.name, required this.firestoreService, required this.myUid});

  @override
  State<_StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<_StatusViewer> {
  int _index = 0;
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    widget.firestoreService.markStatusViewed(widget.statuses[0].id, widget.myUid);
  }

  void _next() {
    if (_index < widget.statuses.length - 1) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.statuses.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                widget.firestoreService.markStatusViewed(widget.statuses[i].id, widget.myUid);
              },
              itemBuilder: (context, i) {
                final url = widget.statuses[i].data()['mediaUrl'] as String?;
                return GestureDetector(
                  onTapUp: (details) {
                    final width = MediaQuery.of(context).size.width;
                    if (details.globalPosition.dx < width / 2) {
                      _prev();
                    } else {
                      _next();
                    }
                  },
                  child: Center(
                    child: url != null ? Image.network(url, fit: BoxFit.contain) : const Icon(Icons.image_not_supported, color: Colors.white54, size: 48),
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
                  widget.statuses.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _index ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
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
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

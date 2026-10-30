import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/channel_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/date_chip.dart';
import 'image_viewer_screen.dart';

const _lastSeenKey = 'channel_last_seen_ms';

/// Row shown at the top of the Updates tab. Shows the latest announcement and
/// a "New" badge when there is something you haven't opened yet.
class ChannelTile extends StatefulWidget {
  const ChannelTile({super.key});

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  final _service = ChannelService();
  int _lastSeenMs = 0;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _lastSeenMs = prefs.getInt(_lastSeenKey) ?? 0);
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChannelScreen()));
    _loadLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.channelStream(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final lastPost = data?['lastPostAt'];
        final lastPostMs = lastPost is Timestamp ? lastPost.millisecondsSinceEpoch : 0;
        final unread = lastPostMs > _lastSeenMs;
        final preview = (data?['lastPostText'] as String?) ?? 'Official news and announcements';
        return ListTile(
          leading: const CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.campaign_rounded, color: Colors.white),
          ),
          title: Text('ChatVibe Updates', style: textTheme.titleMedium),
          subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: unread
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                )
              : null,
          onTap: _open,
        );
      },
    );
  }
}

/// Public broadcast channel. Everyone reads; admins get a compose bar.
class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _service = ChannelService();
  final _storage = StorageService();
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  late final String _myUid = AuthService().currentUser!.uid;
  bool _isAdmin = false;
  bool _sending = false;
  int _limit = 50;

  @override
  void initState() {
    super.initState();
    _service.isAdmin(_myUid).then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
    _markSeen();
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _markSeen();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await _service.post(authorId: _myUid, text: text);
    } catch (e) {
      _toast('Could not post: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final url = await _storage.uploadChannelImage(File(picked.path));
      await _service.post(authorId: _myUid, text: _textCtrl.text, imageUrl: url);
      _textCtrl.clear();
    } catch (e) {
      _toast('Could not post photo: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(String postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Delete this update?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok == true) await _service.deletePost(postId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ChatVibe Updates', style: textTheme.titleLarge),
              Text('Official announcements', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.postsStream(limit: _limit),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Could not load updates:\n${snap.error}', textAlign: TextAlign.center)));
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  final posts = snap.data!.docs;
                  if (posts.isEmpty) {
                    return Center(child: Text('No updates yet', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)));
                  }
                  final canLoadMore = posts.length >= _limit;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: posts.length + (canLoadMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == posts.length) {
                        return Center(child: TextButton(onPressed: () => setState(() => _limit += 50), child: const Text('Load earlier updates')));
                      }
                      final doc = posts[i];
                      final data = doc.data();
                      final at = TimeFormat.fromTs(data['createdAt']) ?? DateTime.now();
                      final older = i + 1 < posts.length ? TimeFormat.fromTs(posts[i + 1].data()['createdAt']) : null;
                      final showDate = i + 1 < posts.length ? (older != null && !TimeFormat.sameDay(older, at)) : !canLoadMore;
                      final imageUrl = data['imageUrl'] as String?;
                      final text = (data['text'] as String?) ?? '';

                      final card = GestureDetector(
                        onLongPress: _isAdmin ? () => _confirmDelete(doc.id) : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bubbleReceivedDark : AppColors.bubbleReceived,
                            borderRadius: BorderRadius.circular(AppRadius.bubble),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageUrl != null)
                                GestureDetector(
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrls: [imageUrl], initialIndex: 0))),
                                  child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover),
                                ),
                              if (text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                                  child: Text(text, style: textTheme.bodyLarge?.copyWith(height: 1.35)),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(TimeFormat.clock(at), style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (!showDate) return card;
                      return Column(mainAxisSize: MainAxisSize.min, children: [DateChip(label: TimeFormat.dayLabel(at)), card]);
                    },
                  );
                },
              ),
            ),
            if (_isAdmin)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                        onPressed: _sending ? null : _sendPhoto,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(hintText: 'Post an update...'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                        child: IconButton(
                          icon: _sending
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                          onPressed: _sending ? null : _sendText,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text('Only admins can post here', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

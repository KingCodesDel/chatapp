import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../screens/image_viewer_screen.dart';
import 'date_chip.dart';

/// A one-way feed of posts (text + optional photo) with date dividers, used by
/// the official updates channel, user channels, and community announcements.
/// If [canPost] is true a compose bar appears at the bottom.
class BroadcastFeed extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(int limit) postsStream;
  final bool canPost;
  final String emptyText;
  final String readOnlyHint;
  final Future<void> Function(String text, String? imageUrl) onPost;
  final Future<void> Function(String postId) onDelete;

  const BroadcastFeed({
    super.key,
    required this.postsStream,
    required this.canPost,
    required this.onPost,
    required this.onDelete,
    this.emptyText = 'No posts yet',
    this.readOnlyHint = 'Only the owner can post here',
  });

  @override
  State<BroadcastFeed> createState() => _BroadcastFeedState();
}

class _BroadcastFeedState extends State<BroadcastFeed> {
  final _storage = StorageService();
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  bool _sending = false;
  int _limit = 50;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = widget.postsStream(_limit);

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await widget.onPost(text, null);
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
      await widget.onPost(_textCtrl.text, url);
      _textCtrl.clear();
    } catch (e) {
      _toast('Could not post photo: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(String postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok == true) await widget.onDelete(postId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Could not load posts:\n${snap.error}', textAlign: TextAlign.center)));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              final posts = snap.data!.docs;
              if (posts.isEmpty) {
                return Center(child: Text(widget.emptyText, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)));
              }
              final canLoadMore = posts.length >= _limit;
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: posts.length + (canLoadMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == posts.length) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _limit += 50;
                          _stream = widget.postsStream(_limit);
                        }),
                        child: const Text('Load earlier posts'),
                      ),
                    );
                  }
                  final doc = posts[i];
                  final data = doc.data();
                  final at = TimeFormat.fromTs(data['createdAt']) ?? DateTime.now();
                  final older = i + 1 < posts.length ? TimeFormat.fromTs(posts[i + 1].data()['createdAt']) : null;
                  final showDate = i + 1 < posts.length ? (older != null && !TimeFormat.sameDay(older, at)) : !canLoadMore;
                  final imageUrl = data['imageUrl'] as String?;
                  final text = (data['text'] as String?) ?? '';

                  final card = GestureDetector(
                    onLongPress: widget.canPost ? () => _confirmDelete(doc.id) : null,
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
        SafeArea(
          top: false,
          child: widget.canPost
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.primary), onPressed: _sending ? null : _sendPhoto),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(hintText: 'Write a post...'),
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
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(widget.readOnlyHint, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ),
        ),
      ],
    );
  }
}

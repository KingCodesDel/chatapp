import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/channel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/broadcast_feed.dart';
import '../widgets/user_avatar.dart';

const _lastSeenKey = 'channel_last_seen_ms';

/// Row shown at the top of the Updates tab for the official "ChatVibe Updates"
/// channel, with a "New" badge when there is something you haven't opened yet.
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
          leading: const CircleAvatar(radius: 26, backgroundColor: AppColors.primary, child: Icon(Icons.campaign_rounded, color: Colors.white)),
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

/// A channel feed: the official one (default) or any user-created channel.
class ChannelScreen extends StatefulWidget {
  final String channelId;
  const ChannelScreen({super.key, this.channelId = ChannelService.officialId});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _service = ChannelService();
  late final String _myUid = AuthService().currentUser!.uid;
  late final _channelStream = _service.channelStream(widget.channelId);
  bool _officialAdmin = false;

  bool get _isOfficial => widget.channelId == ChannelService.officialId;

  @override
  void initState() {
    super.initState();
    if (_isOfficial) {
      _service.isAppAdmin(_myUid).then((v) {
        if (mounted) setState(() => _officialAdmin = v);
      });
      _markSeen();
    }
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    if (_isOfficial) _markSeen();
    super.dispose();
  }

  Future<void> _deleteChannel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this channel?'),
        content: const Text('All followers will lose access. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteChannel(widget.channelId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _channelStream,
      builder: (context, snap) {
        final data = snap.data?.data();
        final deleted = snap.hasData && !snap.data!.exists && !_isOfficial;
        final name = _isOfficial ? 'ChatVibe Updates' : (data?['name'] as String? ?? 'Channel');
        final followers = List<String>.from(data?['followers'] ?? []);
        final count = (data?['followerCount'] as int?) ?? followers.length;
        final isOwner = data?['ownerId'] == _myUid;
        final following = followers.contains(_myUid);
        final canPost = _isOfficial ? _officialAdmin : isOwner;

        return AppBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Row(
                children: [
                  if (_isOfficial)
                    const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.campaign_rounded, color: Colors.white, size: 20))
                  else
                    UserAvatar(label: name, photoUrl: data?['photoUrl'] as String?, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium),
                        Text(_isOfficial ? 'Official announcements' : '$count follower${count == 1 ? '' : 's'}',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (!_isOfficial && data != null && !isOwner)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => following ? _service.unfollow(widget.channelId, _myUid) : _service.follow(widget.channelId, _myUid),
                      child: Text(following ? 'Following' : 'Follow'),
                    ),
                  ),
                if (isOwner && !_isOfficial)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') _deleteChannel();
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete channel'))],
                  ),
              ],
            ),
            body: deleted
                ? const Center(child: Text('This channel no longer exists'))
                : Column(
                    children: [
                      if (!_isOfficial && ((data?['description'] as String?) ?? '').isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                          child: Text(data!['description'] as String, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ),
                      Expanded(
                        child: BroadcastFeed(
                          key: ValueKey('${widget.channelId}-$canPost'),
                          postsStream: (limit) => _service.postsStream(widget.channelId, limit: limit),
                          canPost: canPost,
                          emptyText: 'No updates yet',
                          readOnlyHint: _isOfficial ? 'Only admins can post here' : 'Only the channel owner can post',
                          onPost: (text, imageUrl) => _service.post(widget.channelId, authorId: _myUid, text: text, imageUrl: imageUrl),
                          onDelete: (postId) => _service.deletePost(widget.channelId, postId),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/broadcast_feed.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

/// A community: announcements feed + linked group chats.
class CommunityScreen extends StatefulWidget {
  final String communityId;
  const CommunityScreen({super.key, required this.communityId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _service = CommunityService();
  final _firestore = FirestoreService();
  late final String _myUid = AuthService().currentUser!.uid;
  late final _stream = _service.communityStream(widget.communityId);

  Future<void> _openGroup(Map<String, dynamic> group) async {
    final chatId = group['id'] as String;
    try {
      await _service.joinLinkedGroup(chatId, _myUid); // no-op if already a member
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUid: chatId,
          displayName: (group['name'] as String?) ?? 'Group',
          isGroup: true,
          groupPhotoUrl: group['photoUrl'] as String?,
        ),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open group: $e')));
    }
  }

  /// Owner picks one of their own groups to add to the community.
  Future<void> _linkGroup() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('Add one of your groups', style: Theme.of(context).textTheme.titleMedium)),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.chatsStream(_myUid),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    final groups = snap.data!.docs.where((d) {
                      final x = d.data();
                      return x['isGroup'] == true && List<String>.from(x['admins'] ?? []).contains(_myUid);
                    }).toList();
                    if (groups.isEmpty) {
                      return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('You are not an admin of any group yet.\nCreate a group first, then add it here.', textAlign: TextAlign.center)));
                    }
                    return ListView(
                      children: [
                        for (final g in groups)
                          ListTile(
                            leading: UserAvatar(label: (g.data()['groupName'] as String?) ?? 'Group', photoUrl: g.data()['groupPhotoUrl'] as String?, size: 40),
                            title: Text((g.data()['groupName'] as String?) ?? 'Group'),
                            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _service.linkGroup(
                                widget.communityId,
                                chatId: g.id,
                                name: (g.data()['groupName'] as String?) ?? 'Group',
                                photoUrl: (g.data()['groupPhotoUrl'] as String?) ?? '',
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCommunity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this community?'),
        content: const Text('Linked group chats are not deleted. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteCommunity(widget.communityId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasData && !snap.data!.exists) {
          return AppBackdrop(child: Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(), body: const Center(child: Text('This community no longer exists'))));
        }
        final data = snap.data?.data();
        final name = (data?['name'] as String?) ?? 'Community';
        final members = List<String>.from(data?['members'] ?? []);
        final count = (data?['memberCount'] as int?) ?? members.length;
        final isOwner = data?['ownerId'] == _myUid;
        final isMember = members.contains(_myUid);
        final groups = List<Map<String, dynamic>>.from((data?['groups'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

        return DefaultTabController(
          length: 2,
          child: AppBackdrop(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Row(
                  children: [
                    UserAvatar(label: name, photoUrl: data?['photoUrl'] as String?, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium),
                          Text('$count member${count == 1 ? '' : 's'}', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (data != null && !isOwner)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: () => isMember ? _service.leave(widget.communityId, _myUid) : _service.join(widget.communityId, _myUid),
                        child: Text(isMember ? 'Leave' : 'Join'),
                      ),
                    ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _deleteCommunity();
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete community'))],
                    ),
                ],
                bottom: const TabBar(tabs: [Tab(text: 'Announcements'), Tab(text: 'Groups')]),
              ),
              body: TabBarView(
                children: [
                  Column(
                    children: [
                      if (((data?['description'] as String?) ?? '').isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                          child: Text(data!['description'] as String, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ),
                      Expanded(
                        child: (isMember || isOwner)
                            ? BroadcastFeed(
                                key: ValueKey('${widget.communityId}-$isOwner'),
                                postsStream: (limit) => _service.postsStream(widget.communityId, limit: limit),
                                canPost: isOwner,
                                emptyText: 'No announcements yet',
                                readOnlyHint: 'Only the community owner can post announcements',
                                onPost: (text, imageUrl) => _service.post(widget.communityId, authorId: _myUid, text: text, imageUrl: imageUrl),
                                onDelete: (postId) => _service.deletePost(widget.communityId, postId),
                              )
                            : const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('Join this community to see its announcements', textAlign: TextAlign.center))),
                      ),
                    ],
                  ),
                  ListView(
                    children: [
                      if (isOwner)
                        ListTile(
                          leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.add_rounded, color: Colors.white)),
                          title: const Text('Add a group'),
                          onTap: _linkGroup,
                        ),
                      if (groups.isEmpty)
                        const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: Text('No groups linked yet')))
                      else
                        for (final g in groups)
                          ListTile(
                            leading: UserAvatar(label: (g['name'] as String?) ?? 'Group', photoUrl: g['photoUrl'] as String?, size: 44),
                            title: Text((g['name'] as String?) ?? 'Group'),
                            subtitle: Text(isMember || isOwner ? 'Tap to open' : 'Join the community to enter'),
                            trailing: isOwner
                                ? IconButton(icon: const Icon(Icons.link_off_rounded), onPressed: () => _service.unlinkGroup(widget.communityId, g))
                                : null,
                            onTap: (isMember || isOwner) ? () => _openGroup(g) : null,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

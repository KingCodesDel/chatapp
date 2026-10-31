import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/channel_service.dart';
import '../services/community_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/user_avatar.dart';
import 'channel_screen.dart';
import 'community_screen.dart';
import 'create_space_screen.dart';

/// Two rows shown in the Updates tab: Channels and Communities.
class DiscoverTiles extends StatelessWidget {
  const DiscoverTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(radius: 26, backgroundColor: AppColors.accent.withValues(alpha: 0.15), child: const Icon(Icons.podcasts_rounded, color: AppColors.accent)),
          title: Text('Channels', style: textTheme.titleMedium),
          subtitle: const Text('Follow people and topics, or start your own'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen(initialTab: 0))),
        ),
        ListTile(
          leading: CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: const Icon(Icons.groups_rounded, color: AppColors.primary)),
          title: Text('Communities', style: textTheme.titleMedium),
          subtitle: const Text('Announcements and groups in one place'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen(initialTab: 1))),
        ),
      ],
    );
  }
}

/// Browse, search, join and create channels and communities.
class DiscoverScreen extends StatefulWidget {
  final int initialTab;
  const DiscoverScreen({super.key, this.initialTab = 0});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  final _search = TextEditingController();
  final _channels = ChannelService();
  final _communities = CommunityService();
  late final String _myUid = AuthService().currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {}); // refresh the "+" button label
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChannels = _tabs.index == 0;
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Channels & Communities'),
          bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Channels'), Tab(text: 'Communities')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(onChannels ? 'New channel' : 'New community', style: const TextStyle(color: Colors.white)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateSpaceScreen(community: !onChannels))),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search by name...', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SpaceList(
                    query: _search.text.trim().toLowerCase(),
                    myUid: _myUid,
                    memberField: 'followers',
                    countField: 'followerCount',
                    countLabel: 'follower',
                    mineTitle: 'Following',
                    mineStream: _channels.followingStream(_myUid),
                    allStream: _channels.discoverStream(),
                    onOpen: (id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChannelScreen(channelId: id))),
                    emptyText: 'No channels yet - be the first to create one!',
                  ),
                  _SpaceList(
                    query: _search.text.trim().toLowerCase(),
                    myUid: _myUid,
                    memberField: 'members',
                    countField: 'memberCount',
                    countLabel: 'member',
                    mineTitle: 'Your communities',
                    mineStream: _communities.myCommunitiesStream(_myUid),
                    allStream: _communities.discoverStream(),
                    onOpen: (id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityScreen(communityId: id))),
                    emptyText: 'No communities yet - be the first to create one!',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Yours" section followed by a "Discover" section, for channels or communities.
class _SpaceList extends StatelessWidget {
  final String query;
  final String myUid;
  final String memberField;
  final String countField;
  final String countLabel;
  final String mineTitle;
  final Stream<QuerySnapshot<Map<String, dynamic>>> mineStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> allStream;
  final void Function(String id) onOpen;
  final String emptyText;

  const _SpaceList({
    required this.query,
    required this.myUid,
    required this.memberField,
    required this.countField,
    required this.countLabel,
    required this.mineTitle,
    required this.mineStream,
    required this.allStream,
    required this.onOpen,
    required this.emptyText,
  });

  bool _matches(Map<String, dynamic> d) => query.isEmpty || ((d['name'] as String?) ?? '').toLowerCase().contains(query);

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 4),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary)),
      );

  Widget _tile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = (d['name'] as String?) ?? 'Unnamed';
    final count = (d[countField] as int?) ?? 0;
    return ListTile(
      leading: UserAvatar(label: name, photoUrl: d['photoUrl'] as String?, size: 48),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        ((d['description'] as String?) ?? '').isNotEmpty ? d['description'] as String : '$count $countLabel${count == 1 ? '' : 's'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text('$count', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      onTap: () => onOpen(doc.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: mineStream,
      builder: (context, mineSnap) {
        final mine = (mineSnap.data?.docs ?? []).where((d) => _matches(d.data())).toList()
          ..sort((a, b) => ((b.data()['lastPostAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a.data()['lastPostAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: allStream,
          builder: (context, allSnap) {
            if (allSnap.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Could not load:\n${allSnap.error}', textAlign: TextAlign.center)));
            }
            if (!allSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            final others = allSnap.data!.docs
                .where((d) => !List<String>.from(d.data()[memberField] ?? []).contains(myUid) && _matches(d.data()))
                .toList();
            if (mine.isEmpty && others.isEmpty) {
              return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(query.isEmpty ? emptyText : 'Nothing found for "$query"', textAlign: TextAlign.center)));
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                if (mine.isNotEmpty) ...[_header(context, mineTitle), ...mine.map(_tile)],
                if (others.isNotEmpty) ...[_header(context, 'Discover'), ...others.map(_tile)],
              ],
            );
          },
        );
      },
    );
  }
}

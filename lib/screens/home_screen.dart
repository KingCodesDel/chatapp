import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_container.dart';
import '../widgets/user_avatar.dart';
import 'search_screen.dart';
import 'create_group_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  static const _titles = ['Chats', 'Groups', 'Status'];
  static const double _navHeight = 64;
  static const double _navMargin = AppSpacing.md;
  static const double _navGap = AppSpacing.sm; // gap between nav bar and FAB above it

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 12),
          child: GlassContainer(
            blur: 20,
            child: AppBar(
              titleSpacing: 8,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _firestoreService.userStream(myUid),
                      builder: (context, snap) {
                        if (!snap.hasData || !snap.data!.exists) return const SizedBox(width: 34, height: 34);
                        final me = AppUser.fromMap(snap.data!.data()!);
                        return UserAvatar(label: me.username, photoUrl: me.photoUrl, size: 34);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_titles[_tabIndex]),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        // Everything below is a Stack instead of Scaffold's bottomNavigationBar
        // slot on purpose: bottomNavigationBar reserves a fixed strip flush
        // with the screen edge, which reads as "attached." A Positioned
        // overlay lets the nav bar float above the content with visible
        // margin on all four sides, and content scrolls underneath it.
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: _tabIndex,
                  children: const [_ChatsTab(), _GroupsTab(), StatusScreen()],
                ),
              ),
            ),
            if (_tabIndex != 2)
              Positioned(
                right: _navMargin,
                bottom: bottomSafe + _navMargin + _navHeight + _navGap,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: FloatingActionButton(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: () {
                      if (_tabIndex == 0) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
                      }
                    },
                    child: Icon(_tabIndex == 0 ? Icons.person_search_rounded : Icons.group_add_rounded, color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              left: _navMargin,
              right: _navMargin,
              bottom: bottomSafe + _navMargin,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(28),
                  blur: 24,
                  child: SizedBox(
                    height: _navHeight,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestoreService.chatsStream(myUid),
                      builder: (context, snap) {
                        int chatsUnread = 0;
                        int groupsUnread = 0;
                        for (final doc in snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                          final data = doc.data();
                          final count = (data['unreadCounts'] as Map<String, dynamic>?)?[myUid] as int? ?? 0;
                          if (data['isGroup'] == true) {
                            groupsUnread += count;
                          } else {
                            chatsUnread += count;
                          }
                        }
                        return Row(
                          children: [
                            _NavItem(
                              iconOutline: Icons.chat_bubble_outline_rounded,
                              iconFilled: Icons.chat_bubble_rounded,
                              label: 'Chats',
                              selected: _tabIndex == 0,
                              badgeCount: chatsUnread,
                              onTap: () => setState(() => _tabIndex = 0),
                            ),
                            _NavItem(
                              iconOutline: Icons.groups_2_outlined,
                              iconFilled: Icons.groups_2_rounded,
                              label: 'Groups',
                              selected: _tabIndex == 1,
                              badgeCount: groupsUnread,
                              onTap: () => setState(() => _tabIndex = 1),
                            ),
                            _NavItem(
                              iconOutline: Icons.circle_outlined,
                              iconFilled: Icons.blur_circular_rounded,
                              label: 'Status',
                              selected: _tabIndex == 2,
                              badgeCount: 0,
                              onTap: () => setState(() => _tabIndex = 2),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData iconOutline;
  final IconData iconFilled;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconOutline,
    required this.iconFilled,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selected ? iconFilled : iconOutline, color: color, size: 22),
                    const SizedBox(height: 2),
                    Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                  ],
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    return _ChatList(isGroup: false);
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context) {
    return _ChatList(isGroup: true);
  }
}

class _ChatList extends StatelessWidget {
  final bool isGroup;
  const _ChatList({required this.isGroup});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final myUid = authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestoreService.chatsStream(myUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Error loading chats:\n${snapshot.error}', textAlign: TextAlign.center, style: textTheme.bodyMedium),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final chats = snapshot.data!.docs.where((d) => (d.data()['isGroup'] == true) == isGroup).toList();

        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isGroup ? Icons.groups_outlined : Icons.forum_outlined, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(isGroup ? 'No groups yet' : 'No chats yet', style: textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(isGroup ? 'Tap + to create a group' : 'Tap + to start a chat',
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 110),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chat = chatDoc.data();

            if (isGroup) {
              final groupName = chat['groupName'] as String? ?? 'Group';
              final groupPhotoUrl = chat['groupPhotoUrl'] as String?;
              return Dismissible(
                key: Key(chatDoc.id),
                direction: DismissDirection.endToStart,
                background: _deleteBackground(),
                confirmDismiss: (_) => _confirmLeaveGroup(context),
                onDismissed: (_) => firestoreService.leaveGroup(chatDoc.id, myUid),
                child: _ChatRow(
                  displayName: groupName,
                  photoUrl: groupPhotoUrl,
                  lastMessage: chat['lastMessage'] as String? ?? '',
                  unreadCount: (chat['unreadCounts'] as Map<String, dynamic>?)?[myUid] as int? ?? 0,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(otherUid: chatDoc.id, displayName: groupName, isGroup: true, groupPhotoUrl: groupPhotoUrl),
                  )),
                ),
              );
            }

            final participants = List<String>.from(chat['participants']);
            final otherUid = participants.firstWhere((id) => id != myUid);

            return FutureBuilder<AppUser?>(
              future: firestoreService.getUser(otherUid),
              builder: (context, userSnap) {
                if (!userSnap.hasData || userSnap.data == null) return const SizedBox(height: 72);
                final otherUser = userSnap.data!;

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: firestoreService.contactStream(myUid, otherUid),
                  builder: (context, contactSnap) {
                    String displayName = otherUser.username;
                    if (contactSnap.hasData && contactSnap.data!.exists) {
                      final nickname = contactSnap.data!.data()?['nickname'] as String?;
                      if (nickname != null && nickname.trim().isNotEmpty) displayName = nickname;
                    }

                    return Dismissible(
                      key: Key(chatDoc.id),
                      direction: DismissDirection.endToStart,
                      background: _deleteBackground(),
                      confirmDismiss: (_) => _confirmDeleteChat(context),
                      onDismissed: (_) => firestoreService.deleteChat(chatDoc.id),
                      child: _ChatRow(
                        displayName: displayName,
                        photoUrl: otherUser.photoUrl,
                        lastMessage: chat['lastMessage'] as String? ?? '',
                        unreadCount: (chat['unreadCounts'] as Map<String, dynamic>?)?[myUid] as int? ?? 0,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => ChatScreen(otherUid: otherUid, displayName: displayName, otherPhotoUrl: otherUser.photoUrl)),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: Colors.red,
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }

  Future<bool> _confirmDeleteChat(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Delete this chat?'),
        content: const Text('This removes the conversation from your list. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    return confirm ?? false;
  }

  Future<bool> _confirmLeaveGroup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Leave this group?'),
        content: const Text("You'll need to be re-added to rejoin."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('LEAVE')),
        ],
      ),
    );
    return confirm ?? false;
  }
}

class _ChatRow extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final String lastMessage;
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatRow({
    required this.displayName,
    required this.photoUrl,
    required this.lastMessage,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unread = unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        child: Row(
          children: [
            UserAvatar(label: displayName, photoUrl: photoUrl, size: 52),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage.isNotEmpty ? lastMessage : 'Say hi 👋',
                    style: textTheme.bodySmall?.copyWith(
                      color: unread ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                constraints: const BoxConstraints(minWidth: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_container.dart';
import '../widgets/user_avatar.dart';
import '../widgets/message_bubble.dart';
import 'contact_profile_screen.dart';
import 'group_info_screen.dart';
import 'image_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  /// For a 1:1 chat, pass the other user's uid via [otherUid].
  /// For a group chat, pass [isGroup]: true and the chat's own id via [otherUid].
  final String otherUid;
  final String displayName;
  final bool isGroup;
  final String? groupPhotoUrl;
  final String? otherPhotoUrl; // the other person's profile photo, for 1:1 chats

  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.displayName,
    this.isGroup = false,
    this.groupPhotoUrl,
    this.otherPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _storageService = StorageService();
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  String? _chatId;
  String? _initError;
  Timer? _typingTimer;
  bool _uploadingImage = false;
  String? _editingMessageId;

  final Map<String, String> _senderNames = {};
  int? _unreadAtOpen; // captured once, so the divider position doesn't shift as messages get marked read

  @override
  void initState() {
    super.initState();
    _init();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_chatId != null) {
      _firestoreService.setTyping(_chatId!, _authService.currentUser!.uid, false);
    }
    _textController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final myUid = _authService.currentUser!.uid;
    try {
      final chatId = widget.isGroup ? widget.otherUid : await _firestoreService.getOrCreateChat(myUid, widget.otherUid);
      if (mounted) setState(() => _chatId = chatId);
      if (widget.isGroup) _loadSenderNames(chatId);
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  Future<void> _loadSenderNames(String chatId) async {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    for (final uid in participants) {
      final user = await _firestoreService.getUser(uid);
      if (user != null && mounted) {
        setState(() => _senderNames[uid] = user.username);
      }
    }
  }

  void _onTextChanged() {
    if (_chatId == null) return;
    final myUid = _authService.currentUser!.uid;
    _firestoreService.setTyping(_chatId!, myUid, _textController.text.isNotEmpty);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _firestoreService.setTyping(_chatId!, myUid, false);
    });
  }

  Future<void> _send() async {
    if (_chatId == null) return;
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    if (_editingMessageId != null) {
      await _firestoreService.editMessage(_chatId!, _editingMessageId!, text);
      setState(() => _editingMessageId = null);
      _textController.clear();
      return;
    }

    _textController.clear();
    _firestoreService.setTyping(_chatId!, _authService.currentUser!.uid, false);
    await _firestoreService.sendMessage(chatId: _chatId!, senderId: _authService.currentUser!.uid, text: text);
  }

  Future<void> _sendImage() async {
    if (_chatId == null) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _storageService.uploadChatImage(_chatId!, File(picked.path));
      await _firestoreService.sendMessage(chatId: _chatId!, senderId: _authService.currentUser!.uid, text: '', type: 'image', imageUrl: url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send image: $e')));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _showMessageOptions(String messageId, String currentText, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            if (type == 'text')
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessageId = messageId;
                    _textController.text = currentText;
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD64545)),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                await _firestoreService.deleteMessage(_chatId!, messageId);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Block this person?'),
        content: Text("You won't be able to message ${widget.displayName} and they won't be able to message you."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('BLOCK')),
        ],
      ),
    );
    if (confirm != true) return;
    await _firestoreService.blockUser(_authService.currentUser!.uid, widget.otherUid);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reportUser() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Report this person'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'What happened?'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, reasonCtrl.text), child: const Text('SUBMIT')),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _firestoreService.reportUser(reporterUid: _authService.currentUser!.uid, reportedUid: widget.otherUid, reason: reason.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: GlassContainer(
            blur: 20,
            child: AppBar(
              titleSpacing: 0,
              title: InkWell(
                onTap: _chatId == null
                    ? null
                    : widget.isGroup
                        ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoScreen(chatId: _chatId!)))
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ContactProfileScreen(otherUid: widget.otherUid, currentDisplayName: widget.displayName),
                            )),
                child: Row(
                  children: [
                    UserAvatar(label: widget.displayName, photoUrl: widget.isGroup ? widget.groupPhotoUrl : widget.otherPhotoUrl, size: 36),
                    const SizedBox(width: AppSpacing.xs + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.displayName, style: textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                          if (_chatId != null && !widget.isGroup)
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _firestoreService.chatDocStream(_chatId!),
                              builder: (context, snap) {
                                final typing = snap.data?.data()?['typing'] as Map<String, dynamic>?;
                                final otherTyping = typing?[widget.otherUid] == true;
                                if (!otherTyping) return const SizedBox.shrink();
                                return Text('typing...', style: textTheme.bodySmall?.copyWith(color: AppColors.primary));
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!widget.isGroup)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'block') _blockUser();
                      if (value == 'report') _reportUser();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'block', child: Text('Block user')),
                      PopupMenuItem(value: 'report', child: Text('Report user')),
                    ],
                  ),
              ],
            ),
          ),
        ),
        body: _initError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('Error opening chat:\n$_initError', textAlign: TextAlign.center, style: textTheme.bodyMedium),
                ),
              )
            : _chatId == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _firestoreService.messagesStream(_chatId!),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Text('Error loading messages:\n${snapshot.error}', textAlign: TextAlign.center, style: textTheme.bodyMedium),
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                            }
                            final messages = snapshot.data!.docs;
                            _unreadAtOpen ??= messages
                                .where((d) => d.data()['senderId'] != myUid && d.data()['status'] == 'sent')
                                .length;
                            final unreadAtOpen = _unreadAtOpen!;
                            _firestoreService.markMessagesRead(_chatId!, myUid, messages);

                            if (messages.isEmpty) {
                              return Center(child: Text('Say hi 👋', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)));
                            }
                            final showDivider = unreadAtOpen > 0 && unreadAtOpen < messages.length;
                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              itemCount: messages.length + (showDivider ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (showDivider && index == unreadAtOpen) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        const Expanded(child: Divider(indent: 24, endIndent: 12)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                                          child: const Text('New messages', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                                        ),
                                        const Expanded(child: Divider(indent: 12, endIndent: 24)),
                                      ],
                                    ),
                                  );
                                }
                                final msgIndex = (showDivider && index > unreadAtOpen) ? index - 1 : index;
                                final doc = messages[msgIndex];
                                final data = doc.data();
                                final isMe = data['senderId'] == myUid;
                                final type = data['type'] ?? 'text';
                                final deleted = data['deleted'] == true;
                                return MessageBubble(
                                  text: data['text'] ?? '',
                                  isMe: isMe,
                                  type: type,
                                  imageUrl: data['imageUrl'],
                                  status: data['status'] ?? 'sent',
                                  edited: data['edited'] == true,
                                  deleted: deleted,
                                  senderName: widget.isGroup ? _senderNames[data['senderId']] : null,
                                  onLongPress: (isMe && !deleted) ? () => _showMessageOptions(doc.id, data['text'] ?? '', type) : null,
                                  onImageTap: (type == 'image' && data['imageUrl'] != null)
                                      ? () => Navigator.of(context)
                                          .push(MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: data['imageUrl'])))
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            children: [
                              if (_editingMessageId != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      const Expanded(child: Text('Editing message', style: TextStyle(color: AppColors.primary, fontSize: 13))),
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _editingMessageId = null;
                                          _textController.clear();
                                        }),
                                        child: const Icon(Icons.close, size: 16, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: _uploadingImage
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.image_outlined, color: AppColors.primary),
                                    onPressed: _uploadingImage ? null : _sendImage,
                                  ),
                                  Expanded(
                                    child: GlassContainer(
                                      borderRadius: BorderRadius.circular(28),
                                      blur: 14,
                                      child: TextField(
                                        controller: _textController,
                                        style: textTheme.bodyLarge,
                                        decoration: const InputDecoration(
                                          hintText: 'Message...',
                                          border: InputBorder.none,
                                          filled: false,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                        ),
                                        onSubmitted: (_) => _send(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Container(
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                                    child: IconButton(
                                      icon: Icon(_editingMessageId != null ? Icons.check_rounded : Icons.arrow_upward_rounded, color: Colors.white),
                                      onPressed: _send,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

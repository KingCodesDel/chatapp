import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String displayName;
  final bool isGroup;
  final String? groupPhotoUrl;
  final String? otherPhotoUrl;

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
  final _recorder = AudioRecorder();

  String? _chatId;
  String? _initError;
  Timer? _typingTimer;
  bool _uploadingImage = false;
  bool _uploadingFile = false;
  bool _recording = false;
  DateTime? _recordStart;
  String? _editingMessageId;
  Map<String, dynamic>? _replyingTo; // {id, text, sender}
  int _messageLimit = 50;

  final Map<String, String> _senderNames = {};
  int? _unreadAtOpen;
  bool _sendReadReceipts = true;

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
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final myUid = _authService.currentUser!.uid;
    try {
      final chatId = widget.isGroup ? widget.otherUid : await _firestoreService.getOrCreateChat(myUid, widget.otherUid);
      if (mounted) setState(() => _chatId = chatId);
      if (widget.isGroup) _loadSenderNames(chatId);
      unawaited(_firestoreService.purgeExpiredMessages(chatId));
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
    unawaited(_loadReadReceiptPref(myUid));
  }

  Future<void> _loadReadReceiptPref(String myUid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    final value = doc.data()?['showReadReceipts'];
    if (mounted) setState(() => _sendReadReceipts = value != false);
  }

  Future<void> _loadSenderNames(String chatId) async {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    for (final uid in participants) {
      final user = await _firestoreService.getUser(uid);
      if (user != null && mounted) setState(() => _senderNames[uid] = user.username);
    }
  }

  void _onTextChanged() {
    if (_chatId == null) return;
    final myUid = _authService.currentUser!.uid;
    _firestoreService.setTyping(_chatId!, myUid, _textController.text.isNotEmpty);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () => _firestoreService.setTyping(_chatId!, myUid, false));
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
    final myUid = _authService.currentUser!.uid;
    _firestoreService.setTyping(_chatId!, myUid, false);
    await _firestoreService.sendMessage(
      chatId: _chatId!,
      senderId: myUid,
      text: text,
      replyToId: _replyingTo?['id'],
      replyToText: _replyingTo?['text'],
      replyToSender: _replyingTo?['sender'],
    );
    if (_replyingTo != null) setState(() => _replyingTo = null);
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

  Future<void> _sendFile() async {
    if (_chatId == null) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    final size = result.files.single.size;
    setState(() => _uploadingFile = true);
    try {
      final url = await _storageService.uploadChatFile(_chatId!, file);
      await _firestoreService.sendMessage(
        chatId: _chatId!,
        senderId: _authService.currentUser!.uid,
        text: '',
        type: 'file',
        fileUrl: url,
        fileName: name,
        fileSize: size,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send file: $e')));
    } finally {
      if (mounted) setState(() => _uploadingFile = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_chatId == null) return;
    if (!_recording) {
      if (!await _recorder.hasPermission()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() {
        _recording = true;
        _recordStart = DateTime.now();
      });
    } else {
      final path = await _recorder.stop();
      final seconds = _recordStart == null ? 0 : DateTime.now().difference(_recordStart!).inSeconds;
      setState(() => _recording = false);
      if (path == null || seconds < 1) return;
      try {
        final url = await _storageService.uploadVoiceMessage(_chatId!, File(path));
        await _firestoreService.sendMessage(
          chatId: _chatId!,
          senderId: _authService.currentUser!.uid,
          text: '',
          type: 'voice',
          audioUrl: url,
          audioSeconds: seconds,
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send voice message: $e')));
      }
    }
  }

  Future<void> _createPoll() async {
    if (_chatId == null) return;
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Text('Create a poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'Question')),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < optionCtrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(controller: optionCtrls[i], decoration: InputDecoration(labelText: 'Option ${i + 1}')),
                  ),
                if (optionCtrls.length < 6)
                  TextButton(
                    onPressed: () => setDialogState(() => optionCtrls.add(TextEditingController())),
                    child: const Text('+ Add option'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CREATE')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final question = questionCtrl.text.trim();
    final options = optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) return;
    await _firestoreService.sendMessage(chatId: _chatId!, senderId: _authService.currentUser!.uid, text: '', type: 'poll', pollQuestion: question, pollOptions: options);
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
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
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded, color: AppColors.primary),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined, color: AppColors.primary),
              title: const Text('Poll'),
              onTap: () {
                Navigator.pop(context);
                _createPoll();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(String messageId, String currentText, String type, bool isStarred) {
    final myUid = _authService.currentUser!.uid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: 10,
                children: _reactionEmojis
                    .map((e) => InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _firestoreService.toggleReaction(_chatId!, messageId, myUid, e);
                          },
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ))
                    .toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = {'id': messageId, 'text': currentText, 'sender': 'You'});
              },
            ),
            if (type == 'text')
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                title: const Text('Copy text'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: currentText));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                },
              ),
            ListTile(
              leading: Icon(isStarred ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber.shade700),
              title: Text(isStarred ? 'Unstar' : 'Star'),
              onTap: () {
                Navigator.pop(context);
                _firestoreService.toggleStar(_chatId!, messageId, myUid);
              },
            ),
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
                          if (_chatId != null)
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _firestoreService.chatDocStream(_chatId!),
                              builder: (context, snap) {
                                final data = snap.data?.data();
                                final typing = data?['typing'] as Map<String, dynamic>?;
                                if (typing == null) return const SizedBox.shrink();
                                if (!widget.isGroup) {
                                  final otherTyping = typing[widget.otherUid] == true;
                                  if (!otherTyping) return const SizedBox.shrink();
                                  return Text('typing...', style: textTheme.bodySmall?.copyWith(color: AppColors.primary));
                                }
                                final typingUids = typing.entries.where((e) => e.value == true && e.key != myUid).map((e) => e.key).toList();
                                if (typingUids.isEmpty) return const SizedBox.shrink();
                                final names = typingUids.map((u) => _senderNames[u] ?? '...').toList();
                                final label = names.length == 1 ? '${names[0]} is typing...' : '${names.join(', ')} are typing...';
                                return Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.primary), overflow: TextOverflow.ellipsis);
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
                          stream: _firestoreService.messagesStream(_chatId!, limit: _messageLimit),
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
                            _unreadAtOpen ??= messages.where((d) => d.data()['senderId'] != myUid && d.data()['status'] == 'sent').length;
                            final unreadAtOpen = _unreadAtOpen!;
                            _firestoreService.markMessagesRead(_chatId!, myUid, messages, sendReadReceipts: _sendReadReceipts);

                            if (messages.isEmpty) {
                              return Center(child: Text('Say hi 👋', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)));
                            }
                            final showDivider = unreadAtOpen > 0 && unreadAtOpen < messages.length;
                            final canLoadMore = messages.length >= _messageLimit;
                            final imageMessages = messages.reversed
                                .where((d) => (d.data()['type'] ?? 'text') == 'image' && d.data()['imageUrl'] != null && d.data()['deleted'] != true)
                                .toList();

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              itemCount: messages.length + (showDivider ? 1 : 0) + (canLoadMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (canLoadMore && index == messages.length + (showDivider ? 1 : 0)) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: TextButton(
                                        onPressed: () => setState(() => _messageLimit += 50),
                                        child: const Text('Load earlier messages'),
                                      ),
                                    ),
                                  );
                                }
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
                                final starredBy = List<String>.from(data['starredBy'] ?? []);
                                final reactions = Map<String, String>.from(data['reactions'] ?? {});
                                final pollVotesRaw = data['pollVotes'] as Map?;

                                return MessageBubble(
                                  text: data['text'] ?? '',
                                  isMe: isMe,
                                  type: type,
                                  imageUrl: data['imageUrl'],
                                  status: data['status'] ?? 'sent',
                                  edited: data['edited'] == true,
                                  deleted: deleted,
                                  senderName: widget.isGroup ? _senderNames[data['senderId']] : null,
                                  replyToText: data['replyToText'],
                                  replyToSender: data['replyToSender'],
                                  reactions: reactions,
                                  currentUid: myUid,
                                  isStarred: starredBy.contains(myUid),
                                  onReactionTap: (emoji) => _firestoreService.toggleReaction(_chatId!, doc.id, myUid, emoji),
                                  audioUrl: data['audioUrl'],
                                  audioSeconds: data['audioSeconds'],
                                  fileUrl: data['fileUrl'],
                                  fileName: data['fileName'],
                                  fileSize: data['fileSize'],
                                  pollQuestion: data['pollQuestion'],
                                  pollOptions: data['pollOptions'] != null ? List<String>.from(data['pollOptions']) : null,
                                  pollVotes: pollVotesRaw?.map((k, v) => MapEntry(k.toString(), List<String>.from(v))),
                                  onVote: type == 'poll' ? (i) => _firestoreService.votePoll(_chatId!, doc.id, myUid, i) : null,
                                  onLongPress: !deleted ? () => _showMessageOptions(doc.id, data['text'] ?? '', type, starredBy.contains(myUid)) : null,
                                  onImageTap: (type == 'image' && data['imageUrl'] != null && !deleted)
                                      ? () {
                                          final urls = imageMessages.map((d) => d.data()['imageUrl'] as String).toList();
                                          final tapIndex = imageMessages.indexWhere((d) => d.id == doc.id);
                                          Navigator.of(context).push(MaterialPageRoute(
                                              builder: (_) => ImageViewerScreen(imageUrls: urls, initialIndex: tapIndex < 0 ? 0 : tapIndex)));
                                        }
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
                              if (_replyingTo != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text('Replying to: ${_replyingTo!['text']}',
                                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                                      ),
                                      GestureDetector(onTap: () => setState(() => _replyingTo = null), child: const Icon(Icons.close, size: 16, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
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
                              if (_recording)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fiber_manual_record, size: 14, color: Colors.red),
                                      SizedBox(width: 6),
                                      Text('Recording... tap the mic again to send', style: TextStyle(color: Colors.red, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: (_uploadingImage || _uploadingFile)
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                                    onPressed: (_uploadingImage || _uploadingFile) ? null : _showAttachmentMenu,
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
                                  ValueListenableBuilder(
                                    valueListenable: _textController,
                                    builder: (context, value, _) {
                                      final hasText = value.text.trim().isNotEmpty || _editingMessageId != null;
                                      return Container(
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? Colors.red : AppColors.primary),
                                        child: IconButton(
                                          icon: Icon(
                                            hasText ? (_editingMessageId != null ? Icons.check_rounded : Icons.arrow_upward_rounded) : (_recording ? Icons.stop_rounded : Icons.mic_rounded),
                                            color: Colors.white,
                                          ),
                                          onPressed: hasText ? _send : _toggleRecording,
                                        ),
                                      );
                                    },
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

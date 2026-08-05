import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- USER SEARCH & PROFILE ----------

  Future<List<AppUser>> searchUsersByUsername(String query, String myUid) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snapshot = await _db
        .collection('users')
        .where('username_lower', isGreaterThanOrEqualTo: q)
        .where('username_lower', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).where((u) => u.uid != myUid).toList();
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateProfile({required String uid, String? photoUrl, String? bio}) async {
    final data = <String, dynamic>{};
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (bio != null) data['bio'] = bio;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // ---------- PRIVACY SETTINGS ----------

  Future<void> updatePrivacySettings({required String uid, bool? showLastSeen, bool? showReadReceipts}) async {
    final data = <String, dynamic>{};
    if (showLastSeen != null) data['showLastSeen'] = showLastSeen;
    if (showReadReceipts != null) data['showReadReceipts'] = showReadReceipts;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // ---------- PRESENCE ----------

  Future<void> setOnline(String uid, bool online) async {
    await _db.collection('users').doc(uid).set({
      'online': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- CONTACTS / NICKNAMES ----------

  Future<void> addOrUpdateContact({required String myUid, required String contactUid, required String nickname}) async {
    await _db.collection('users').doc(myUid).collection('contacts').doc(contactUid).set({
      'contactUid': contactUid,
      'nickname': nickname.trim(),
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> contactStream(String myUid, String contactUid) {
    return _db.collection('users').doc(myUid).collection('contacts').doc(contactUid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> contactsStream(String myUid) {
    return _db.collection('users').doc(myUid).collection('contacts').snapshots();
  }

  // ---------- BLOCK / REPORT ----------

  Future<void> blockUser(String myUid, String otherUid) async {
    await _db.collection('users').doc(myUid).collection('blocked').doc(otherUid).set({
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String myUid, String otherUid) async {
    await _db.collection('users').doc(myUid).collection('blocked').doc(otherUid).delete();
  }

  Stream<bool> isBlockedByMeStream(String myUid, String otherUid) {
    return _db.collection('users').doc(myUid).collection('blocked').doc(otherUid).snapshots().map((d) => d.exists);
  }

  Future<bool> hasBlocked(String uidA, String uidB) async {
    final doc = await _db.collection('users').doc(uidA).collection('blocked').doc(uidB).get();
    return doc.exists;
  }

  Future<void> reportUser({required String reporterUid, required String reportedUid, required String reason}) async {
    await _db.collection('reports').add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- CHATS (1:1) ----------

  String buildChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String> getOrCreateChat(String myUid, String otherUid) async {
    final chatId = buildChatId(myUid, otherUid);
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [myUid, otherUid],
        'isGroup': false,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'typing': {},
      });
    }
    return chatId;
  }

  // ---------- CHATS (groups) ----------

  Future<String> createGroupChat({
    required String creatorUid,
    required List<String> memberUids,
    required String groupName,
    String? groupPhotoUrl,
  }) async {
    final participants = {creatorUid, ...memberUids}.toList();
    final docRef = _db.collection('chats').doc();
    await docRef.set({
      'participants': participants,
      'isGroup': true,
      'groupName': groupName.trim(),
      'groupPhotoUrl': groupPhotoUrl ?? '',
      'admins': [creatorUid],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': '',
      'typing': {},
    });
    return docRef.id;
  }

  Future<void> updateGroupPhoto(String chatId, String photoUrl) async {
    await _db.collection('chats').doc(chatId).update({'groupPhotoUrl': photoUrl});
  }

  /// Chats visible to [myUid], excluding ones they've archived (unless
  /// [includeArchived] is true — used by the Archived screen).
  Stream<QuerySnapshot<Map<String, dynamic>>> chatsStream(String myUid) {
    return _db.collection('chats').where('participants', arrayContains: myUid).orderBy('lastMessageTime', descending: true).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> chatDocStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  Future<void> deleteChat(String chatId) async {
    await _db.collection('chats').doc(chatId).delete();
  }

  Future<void> setMuted(String chatId, String uid, bool muted) async {
    await _db.collection('chats').doc(chatId).set({
      'muted': {uid: muted}
    }, SetOptions(merge: true));
  }

  /// Archives/unarchives a chat for one user only — it just hides it from
  /// their main list, everyone else is unaffected.
  Future<void> setArchived(String chatId, String uid, bool archived) async {
    await _db.collection('chats').doc(chatId).set({
      'archived': {uid: archived}
    }, SetOptions(merge: true));
  }

  /// Sets how long messages in this chat stay visible before disappearing.
  /// Pass null to turn disappearing messages off. Relies on a Firestore TTL
  /// policy configured on the `expiresAt` field of the `messages` collection
  /// group (Firestore Console → your database → TTL tab) — free, no Cloud
  /// Function needed, but you do need to set that policy up once.
  Future<void> setDisappearingSeconds(String chatId, int? seconds) async {
    await _db.collection('chats').doc(chatId).update({'disappearingSeconds': seconds});
  }

  // ---------- INVITE LINKS ----------

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    return List.generate(7, (i) => chars[(rand ~/ (i + 1)) % chars.length]).join();
  }

  /// Creates (or reuses) an invite code for a group and returns it.
  Future<String> createGroupInvite(String chatId) async {
    final existing = await _db.collection('invites').where('chatId', isEqualTo: chatId).limit(1).get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;
    final code = _randomCode();
    await _db.collection('invites').doc(code).set({'chatId': chatId, 'createdAt': FieldValue.serverTimestamp()});
    return code;
  }

  /// Joins the group behind an invite code. Throws if the code is invalid.
  Future<String> joinGroupViaInvite(String code, String myUid) async {
    final inviteDoc = await _db.collection('invites').doc(code.trim().toUpperCase()).get();
    if (!inviteDoc.exists) throw Exception('Invalid or expired invite code');
    final chatId = inviteDoc.data()!['chatId'] as String;
    await _db.collection('chats').doc(chatId).update({'participants': FieldValue.arrayUnion([myUid])});
    return chatId;
  }

  // ---------- TYPING INDICATOR ----------

  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    await _db.collection('chats').doc(chatId).set({
      'typing': {uid: isTyping}
    }, SetOptions(merge: true));
  }

  // ---------- MESSAGES ----------

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String type = 'text',
    String? imageUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    String? audioUrl,
    int? audioSeconds,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    final trimmed = text.trim();
    final hasContent = trimmed.isNotEmpty || imageUrl != null || audioUrl != null || fileUrl != null || pollQuestion != null;
    if (!hasContent) return;

    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final chatSnap = await chatRef.get();
    final chatData = chatSnap.data() ?? {};
    final participants = List<String>.from(chatData['participants'] ?? []);
    final unreadUpdates = <String, dynamic>{
      for (final uid in participants)
        if (uid != senderId) 'unreadCounts.$uid': FieldValue.increment(1),
    };

    Timestamp? expiresAt;
    final disappearingSeconds = chatData['disappearingSeconds'] as int?;
    if (disappearingSeconds != null && disappearingSeconds > 0) {
      expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(seconds: disappearingSeconds)));
    }

    final previewText = switch (type) {
      'image' => '📷 Photo',
      'voice' => '🎤 Voice message',
      'file' => '📎 ${fileName ?? 'File'}',
      'poll' => '📊 ${pollQuestion ?? 'Poll'}',
      _ => trimmed,
    };

    final batch = _db.batch();
    batch.set(
      msgRef,
      Message(
        id: msgRef.id,
        senderId: senderId,
        text: trimmed,
        type: type,
        imageUrl: imageUrl,
        timestamp: Timestamp.now(),
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSender: replyToSender,
        audioUrl: audioUrl,
        audioSeconds: audioSeconds,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        pollQuestion: pollQuestion,
        pollOptions: pollOptions,
        pollVotes: pollOptions != null ? {for (var i = 0; i < pollOptions.length; i++) '$i': <String>[]} : null,
        expiresAt: expiresAt,
      ).toMap(),
    );
    batch.update(chatRef, {
      'lastMessage': previewText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      ...unreadUpdates,
    });
    await batch.commit();
  }

  /// Paginated message stream: newest [limit] messages, descending. Call
  /// again with a larger [limit] to load more (simple approach — refetches
  /// the window rather than true cursor pagination, which keeps the code
  /// simple and is fine for typical chat sizes).
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId, {int limit = 50}) {
    return _db.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: true).limit(limit).snapshots();
  }

  Future<void> markMessagesRead(
    String chatId,
    String myUid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    bool sendReadReceipts = true,
  }) async {
    final batch = _db.batch();
    if (sendReadReceipts) {
      final toUpdate = docs.where((d) => d.data()['senderId'] != myUid && d.data()['status'] == 'sent').toList();
      for (final doc in toUpdate) {
        batch.update(doc.reference, {'status': 'read'});
      }
    }
    batch.update(_db.collection('chats').doc(chatId), {'unreadCounts.$myUid': 0});
    await batch.commit();
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': trimmed,
      'edited': true,
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'deleted': true,
      'text': '',
      'imageUrl': null,
    });
  }

  // ---------- REACTIONS ----------

  Future<void> toggleReaction(String chatId, String messageId, String uid, String emoji) async {
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final snap = await ref.get();
    final reactions = Map<String, dynamic>.from(snap.data()?['reactions'] ?? {});
    if (reactions[uid] == emoji) {
      reactions.remove(uid); // tapping the same emoji again removes it
    } else {
      reactions[uid] = emoji;
    }
    await ref.update({'reactions': reactions});
  }

  // ---------- STARRED MESSAGES ----------

  Future<void> toggleStar(String chatId, String messageId, String uid) async {
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final snap = await ref.get();
    final starredBy = List<String>.from(snap.data()?['starredBy'] ?? []);
    if (starredBy.contains(uid)) {
      await ref.update({'starredBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'starredBy': FieldValue.arrayUnion([uid])});
    }
  }

  /// All messages this user has starred, across every chat. Requires a
  /// Firestore collection-group index on `messages` for `starredBy`
  /// (Firestore will show a one-click link to create it the first time you
  /// run this if it's missing).
  Stream<QuerySnapshot<Map<String, dynamic>>> starredMessagesStream(String uid) {
    return _db.collectionGroup('messages').where('starredBy', arrayContains: uid).snapshots();
  }

  // ---------- POLLS ----------

  Future<void> votePoll(String chatId, String messageId, String uid, int optionIndex) async {
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final snap = await ref.get();
    final votes = Map<String, dynamic>.from(snap.data()?['pollVotes'] ?? {});
    // Remove any previous vote from this user (single-choice poll)
    for (final key in votes.keys) {
      final voters = List<String>.from(votes[key] ?? []);
      voters.remove(uid);
      votes[key] = voters;
    }
    final key = '$optionIndex';
    final voters = List<String>.from(votes[key] ?? []);
    voters.add(uid);
    votes[key] = voters;
    await ref.update({'pollVotes': votes});
  }

  // ---------- GROUP MANAGEMENT ----------

  Future<void> renameGroup(String chatId, String newName) async {
    await _db.collection('chats').doc(chatId).update({'groupName': newName.trim()});
  }

  Future<void> addGroupMembers(String chatId, List<String> uids) async {
    await _db.collection('chats').doc(chatId).update({'participants': FieldValue.arrayUnion(uids)});
  }

  Future<void> removeGroupMember(String chatId, String uid) async {
    await _db.collection('chats').doc(chatId).update({'participants': FieldValue.arrayRemove([uid])});
  }

  Future<void> leaveGroup(String chatId, String myUid) async {
    await removeGroupMember(chatId, myUid);
  }

  // ---------- STATUS UPDATES ----------

  Future<void> postStatus({
    required String uid,
    String type = 'image',
    String? mediaUrl,
    String? caption,
    String? text,
    int? bgColor,
  }) async {
    await _db.collection('status_updates').add({
      'uid': uid,
      'type': type,
      'mediaUrl': mediaUrl,
      'caption': caption ?? '',
      'text': text,
      'bgColor': bgColor,
      'createdAt': FieldValue.serverTimestamp(),
      'viewedBy': <String>[],
    });
  }

  Future<void> deleteStatus(String statusId) async {
    await _db.collection('status_updates').doc(statusId).delete();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getRecentStatuses(List<String> uids) async {
    if (uids.isEmpty) return [];
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 30) {
      chunks.add(uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30));
    }
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final chunk in chunks) {
      final snap = await _db.collection('status_updates').where('uid', whereIn: chunk).get();
      results.addAll(snap.docs.where((d) {
        final ts = d.data()['createdAt'] as Timestamp?;
        return ts != null && ts.compareTo(cutoff) > 0;
      }));
    }
    return results;
  }

  Future<void> markStatusViewed(String statusId, String myUid) async {
    await _db.collection('status_updates').doc(statusId).update({
      'viewedBy': FieldValue.arrayUnion([myUid])
    });
  }
}

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

  Stream<QuerySnapshot<Map<String, dynamic>>> chatsStream(String myUid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> chatDocStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
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
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null) return;

    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

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
      ).toMap(),
    );
    batch.update(chatRef, {
      'lastMessage': type == 'image' ? '📷 Photo' : trimmed,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    });
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _db.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: true).snapshots();
  }

  /// Marks messages NOT sent by [myUid] as read, given the docs already
  /// loaded from messagesStream (avoids needing another composite index).
  Future<void> markMessagesRead(String chatId, String myUid, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final toUpdate = docs.where((d) => d.data()['senderId'] != myUid && d.data()['status'] == 'sent').toList();
    if (toUpdate.isEmpty) return;
    final batch = _db.batch();
    for (final doc in toUpdate) {
      batch.update(doc.reference, {'status': 'read'});
    }
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

  /// Soft-deletes a message (keeps the doc so the timeline doesn't shift,
  /// but clears its content and flags it so the UI shows "message deleted").
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'deleted': true,
      'text': '',
      'imageUrl': null,
    });
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

  Future<void> postStatus({required String uid, String? mediaUrl, String? caption}) async {
    await _db.collection('status_updates').add({
      'uid': uid,
      'mediaUrl': mediaUrl,
      'caption': caption ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'viewedBy': <String>[],
    });
  }

  /// Returns status updates from the given uids (contacts + self) posted in
  /// the last 24 hours. Filters expiry client-side to avoid an extra
  /// composite index.
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

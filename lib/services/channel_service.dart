import 'package:cloud_firestore/cloud_firestore.dart';

/// Channels: one-way broadcast feeds. Anyone can create one, anyone can follow
/// it, only the owner posts.
///
/// There is also one official channel, "ChatVibe Updates" (id [officialId]),
/// that every user sees. Its posters are the uids listed in Firestore doc
/// `config/app` -> field `admins` (see SETUP_NOTES.md).
class ChannelService {
  static const officialId = 'app_updates';
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _channels => _db.collection('channels');
  DocumentReference<Map<String, dynamic>> _channel(String id) => _channels.doc(id);
  CollectionReference<Map<String, dynamic>> _posts(String id) => _channel(id).collection('posts');

  // ----- reading -----

  Stream<DocumentSnapshot<Map<String, dynamic>>> channelStream([String id = officialId]) => _channel(id).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream(String id, {int limit = 50}) {
    return _posts(id).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  /// Channels this user follows (newest activity first is sorted client-side
  /// so no extra Firestore index is needed).
  Stream<QuerySnapshot<Map<String, dynamic>>> followingStream(String uid) {
    return _channels.where('followers', arrayContains: uid).snapshots();
  }

  /// Most-followed channels, for the Discover list.
  Stream<QuerySnapshot<Map<String, dynamic>>> discoverStream({int limit = 50}) {
    return _channels.orderBy('followerCount', descending: true).limit(limit).snapshots();
  }

  // ----- permissions -----

  Future<bool> isAppAdmin(String uid) async {
    try {
      final doc = await _db.collection('config').doc('app').get();
      return List<String>.from(doc.data()?['admins'] ?? []).contains(uid);
    } catch (_) {
      return false;
    }
  }

  /// Can [uid] post in this channel?
  Future<bool> canPost(String channelId, String uid, Map<String, dynamic>? channelData) async {
    if (channelId == officialId) return isAppAdmin(uid);
    return channelData?['ownerId'] == uid;
  }

  // ----- creating / following -----

  Future<String> create({required String ownerId, required String name, String description = '', String photoUrl = ''}) async {
    final ref = _channels.doc();
    await ref.set({
      'name': name.trim(),
      'description': description.trim(),
      'photoUrl': photoUrl,
      'ownerId': ownerId,
      'followers': [ownerId],
      'followerCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> follow(String channelId, String uid) {
    return _channel(channelId).update({
      'followers': FieldValue.arrayUnion([uid]),
      'followerCount': FieldValue.increment(1),
    });
  }

  Future<void> unfollow(String channelId, String uid) {
    return _channel(channelId).update({
      'followers': FieldValue.arrayRemove([uid]),
      'followerCount': FieldValue.increment(-1),
    });
  }

  Future<void> deleteChannel(String channelId) => _channel(channelId).delete();

  // ----- posting -----

  Future<void> post(String channelId, {required String authorId, String text = '', String? imageUrl}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null) return;
    await _posts(channelId).add({
      'authorId': authorId,
      'text': trimmed,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _channel(channelId).set({
      if (channelId == officialId) 'name': 'ChatVibe Updates',
      'lastPostAt': FieldValue.serverTimestamp(),
      'lastPostText': trimmed.isNotEmpty ? trimmed : '📷 Photo',
    }, SetOptions(merge: true));
  }

  Future<void> deletePost(String channelId, String postId) => _posts(channelId).doc(postId).delete();
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Communities: a place that bundles an announcement feed (owner posts, members
/// read) with a list of linked group chats members can join.
///
/// Linked groups are stored inside the community document as
/// `groups: [{id, name, photoUrl}]` so members can see them before joining
/// (group chat documents themselves are only readable by their members).
class CommunityService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _communities => _db.collection('communities');
  DocumentReference<Map<String, dynamic>> _doc(String id) => _communities.doc(id);
  CollectionReference<Map<String, dynamic>> _posts(String id) => _doc(id).collection('posts');

  Stream<DocumentSnapshot<Map<String, dynamic>>> communityStream(String id) => _doc(id).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream(String id, {int limit = 50}) {
    return _posts(id).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myCommunitiesStream(String uid) {
    return _communities.where('members', arrayContains: uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> discoverStream({int limit = 50}) {
    return _communities.orderBy('memberCount', descending: true).limit(limit).snapshots();
  }

  Future<String> create({required String ownerId, required String name, String description = '', String photoUrl = ''}) async {
    final ref = _communities.doc();
    await ref.set({
      'name': name.trim(),
      'description': description.trim(),
      'photoUrl': photoUrl,
      'ownerId': ownerId,
      'members': [ownerId],
      'memberCount': 1,
      'groups': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> join(String id, String uid) {
    return _doc(id).update({
      'members': FieldValue.arrayUnion([uid]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> leave(String id, String uid) {
    return _doc(id).update({
      'members': FieldValue.arrayRemove([uid]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Future<void> deleteCommunity(String id) => _doc(id).delete();

  // ----- linked groups (owner only) -----

  Future<void> linkGroup(String communityId, {required String chatId, required String name, String photoUrl = ''}) {
    return _doc(communityId).update({
      'groups': FieldValue.arrayUnion([
        {'id': chatId, 'name': name, 'photoUrl': photoUrl}
      ]),
    });
  }

  Future<void> unlinkGroup(String communityId, Map<String, dynamic> group) {
    return _doc(communityId).update({
      'groups': FieldValue.arrayRemove([group]),
    });
  }

  /// Adds you to a linked group chat (the existing chat rules allow this).
  Future<void> joinLinkedGroup(String chatId, String uid) {
    return _db.collection('chats').doc(chatId).update({'participants': FieldValue.arrayUnion([uid])});
  }

  // ----- announcements (owner only) -----

  Future<void> post(String communityId, {required String authorId, String text = '', String? imageUrl}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null) return;
    await _posts(communityId).add({
      'authorId': authorId,
      'text': trimmed,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _doc(communityId).update({
      'lastPostAt': FieldValue.serverTimestamp(),
      'lastPostText': trimmed.isNotEmpty ? trimmed : '📷 Photo',
    });
  }

  Future<void> deletePost(String communityId, String postId) => _posts(communityId).doc(postId).delete();
}

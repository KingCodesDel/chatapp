import 'package:cloud_firestore/cloud_firestore.dart';

/// The public "ChatVibe Updates" channel: everyone can read, only admins can post.
///
/// Admins are the uids listed in the Firestore document `config/app`
/// (field `admins`, an array of strings). You add yourself there once from the
/// Firebase console - see SETUP_NOTES.md. Because that document can't be
/// written from the app, nobody can make themselves an admin.
class ChannelService {
  static const channelId = 'app_updates';
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _channel => _db.collection('channels').doc(channelId);
  CollectionReference<Map<String, dynamic>> get _posts => _channel.collection('posts');

  Stream<DocumentSnapshot<Map<String, dynamic>>> channelStream() => _channel.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream({int limit = 50}) {
    return _posts.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _db.collection('config').doc('app').get();
      return List<String>.from(doc.data()?['admins'] ?? []).contains(uid);
    } catch (_) {
      return false;
    }
  }

  Future<void> post({required String authorId, String text = '', String? imageUrl}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null) return;
    await _posts.add({
      'authorId': authorId,
      'text': trimmed,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _channel.set({
      'name': 'ChatVibe Updates',
      'lastPostAt': FieldValue.serverTimestamp(),
      'lastPostText': trimmed.isNotEmpty ? trimmed : '📷 Photo',
    }, SetOptions(merge: true));
  }

  Future<void> deletePost(String postId) => _posts.doc(postId).delete();
}

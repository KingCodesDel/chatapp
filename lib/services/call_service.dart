import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'push_api.dart';

/// Wraps LiveKit for voice/video calls. Firestore stays the source of
/// truth for "is there an active call in this room/chat" and who's in it;
/// LiveKit only carries the actual audio/video media.
///
/// IMPORTANT: the LiveKit API key/secret must never live in the Flutter
/// app. Token minting happens in a Cloud Function (`getLiveKitToken`,
/// see project Cloud Functions notes) which verifies the caller is a
/// member of the room/chat before issuing a token scoped to it.
class CallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  lk.Room? _room;
  lk.Room? get room => _room;

  /// Marks a call as active for [chatOrRoomId] and returns a connected
  /// LiveKit [lk.Room]. [chatOrRoomId] doubles as the LiveKit room name —
  /// keeping a 1:1 mapping avoids needing a separate lookup table.
  Future<lk.Room> startOrJoinCall({
    required String chatOrRoomId,
    required String uid,
    required String collectionPath, // 'chats' or 'rooms'
  }) async {
    // Token comes from your free Cloudflare Worker (no Cloud Functions needed).
    final result = await PushApi.callToken(chatOrRoomId, collectionPath);
    final token = result['token'] as String;
    final url = result['url'] as String;

    final room = lk.Room();
    await room.connect(url, token);
    _room = room;

    final callRef = _db.collection(collectionPath).doc(chatOrRoomId).collection('meta').doc('liveCall');
    await callRef.set({
      'active': true,
      'startedAt': FieldValue.serverTimestamp(),
      'participantUids': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));

    return room;
  }

  Future<void> leaveCall({
    required String chatOrRoomId,
    required String uid,
    required String collectionPath,
  }) async {
    await _room?.disconnect();
    _room = null;

    final callRef = _db.collection(collectionPath).doc(chatOrRoomId).collection('meta').doc('liveCall');
    await callRef.update({
      'participantUids': FieldValue.arrayRemove([uid]),
    });
    final snap = await callRef.get();
    final participants = List<String>.from(snap.data()?['participantUids'] ?? []);
    if (participants.isEmpty) {
      await callRef.update({'active': false});
    }
  }

  /// True if someone is currently in a call for this chat/room.
  Future<bool> isActive(String chatOrRoomId, String collectionPath) async {
    try {
      final snap = await _db.collection(collectionPath).doc(chatOrRoomId).collection('meta').doc('liveCall').get();
      final d = snap.data();
      return d != null && d['active'] == true && List.from(d['participantUids'] ?? []).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> activeCallStream(String chatOrRoomId, String collectionPath) {
    return _db.collection(collectionPath).doc(chatOrRoomId).collection('meta').doc('liveCall').snapshots();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final String type; // 'text' or 'image'
  final String? imageUrl;
  final String status; // 'sent' or 'read'
  final bool edited;
  final bool deleted;
  final Timestamp timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.imageUrl,
    this.status = 'sent',
    this.edited = false,
    this.deleted = false,
    required this.timestamp,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'sent',
      edited: map['edited'] ?? false,
      deleted: map['deleted'] ?? false,
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'status': status,
      'edited': edited,
      'deleted': deleted,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

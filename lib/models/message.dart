import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final String type; // 'text' | 'image' | 'voice' | 'file' | 'poll'
  final String? imageUrl;
  final String status; // 'sent' or 'read'
  final Timestamp timestamp;
  final bool edited;
  final bool deleted;
  final Map<String, String> reactions; // uid -> emoji
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final List<String> starredBy;
  // voice
  final String? audioUrl;
  final int? audioSeconds;
  // file
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  // poll
  final String? pollQuestion;
  final List<String>? pollOptions;
  final Map<String, List<String>>? pollVotes; // optionIndex(as string) -> [uids]

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.imageUrl,
    this.status = 'sent',
    required this.timestamp,
    this.edited = false,
    this.deleted = false,
    this.reactions = const {},
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.starredBy = const [],
    this.audioUrl,
    this.audioSeconds,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'sent',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      edited: map['edited'] == true,
      deleted: map['deleted'] == true,
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      replyToSender: map['replyToSender'],
      starredBy: List<String>.from(map['starredBy'] ?? []),
      audioUrl: map['audioUrl'],
      audioSeconds: map['audioSeconds'],
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      pollQuestion: map['pollQuestion'],
      pollOptions: map['pollOptions'] != null ? List<String>.from(map['pollOptions']) : null,
      pollVotes: map['pollVotes'] != null
          ? (map['pollVotes'] as Map).map((k, v) => MapEntry(k.toString(), List<String>.from(v)))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
      'edited': edited,
      'deleted': deleted,
      'reactions': reactions,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'starredBy': starredBy,
      'audioUrl': audioUrl,
      'audioSeconds': audioSeconds,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'pollVotes': pollVotes,
    };
  }
}

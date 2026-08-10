import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Handles push notification setup. Sending the actual notification when a
/// message arrives happens server-side (see /functions/index.js) — this
/// class only handles the client's half: permission, token storage, and
/// showing a banner while the app is open.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Call once after login. Requests permission, saves the device's FCM
  /// token to the user's profile so the Cloud Function knows where to send
  /// notifications, and keeps it updated if it ever rotates.
  Future<void> init(String uid) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(uid, token);
    }
    _messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Shows a simple in-app banner for messages that arrive while the app is
  /// open and in the foreground (system tray handles background/terminated
  /// automatically once the Cloud Function is deployed).
  void listenForegroundMessages(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title == null || body == null) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title: $body'), duration: const Duration(seconds: 3)),
      );
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/push_config.dart';

/// Talks to your free Cloudflare Worker. Every request carries the signed-in
/// user's Firebase ID token so the Worker knows who is asking.
class PushApi {
  static Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final token = await user.getIdToken();
    return http
        .post(
          Uri.parse('$kPushWorkerUrl$path'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
  }

  static Future<void> _fire(String path, Map<String, dynamic> body) async {
    try {
      await _post(path, body);
    } catch (e) {
      debugPrint('Push request failed: $e');
    }
  }

  /// Tells the Worker to push-notify the other people in [chatId] about a message
  /// you just sent. Fire-and-forget: a failure never blocks sending.
  static void notifyMessage(String chatId, String messageId) {
    if (!kPushConfigured) return;
    unawaited(_fire('/push', {'kind': 'message', 'chatId': chatId, 'messageId': messageId}));
  }

  /// Rings everyone else in [chatId].
  static void notifyCall(String chatId, {required bool video}) {
    if (!kPushConfigured) return;
    unawaited(_fire('/push', {'kind': 'call', 'chatId': chatId, 'video': video}));
  }

  /// Gets a LiveKit token for a call (replaces the old Cloud Function).
  static Future<Map<String, dynamic>> callToken(String roomName, String collection) async {
    if (!kPushConfigured) {
      throw Exception('Calls are not set up yet: set kPushWorkerUrl in lib/config/push_config.dart');
    }
    final res = await _post('/call-token', {'roomName': roomName, 'collection': collection});
    if (res.statusCode != 200) {
      throw Exception('Call server error ${res.statusCode}: ${res.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }
}

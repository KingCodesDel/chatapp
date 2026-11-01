import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/chat_screen.dart';
import '../screens/incoming_call_screen.dart';

/// Lets notification taps open screens from outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Client half of push notifications: permission, saving this phone's FCM token
/// to the user's profile, showing alerts while the app is open, and opening the
/// right chat / incoming-call screen when a notification is tapped.
/// (When the app is closed or in the background, Android shows the push itself.)
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Chat currently on screen - pushes for it are not shown.
  static String? activeChatId;

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _listening = false;
  bool _showingCall = false;
  String? _uid;

  static const _messagesChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'New message alerts',
    importance: Importance.high,
  );
  static const _callsChannel = AndroidNotificationChannel(
    'calls',
    'Calls',
    description: 'Incoming call alerts',
    importance: Importance.max,
  );

  Future<void> init(String uid) async {
    _uid = uid;
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      if (!_listening) {
        _listening = true;
        await _initLocal();
        _fcm.onTokenRefresh.listen(_saveToken);
        FirebaseMessaging.onMessage.listen(_onForeground);
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
        final initial = await _fcm.getInitialMessage();
        if (initial != null) {
          Future.delayed(const Duration(milliseconds: 1500), () => _openFromData(initial.data));
        }
      }
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  Future<void> _initLocal() async {
    await _local.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          _openFromData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {}
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_messagesChannel);
    await android?.createNotificationChannel(_callsChannel);
    await android?.requestNotificationsPermission();
  }

  Future<void> _saveToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Call before signing out so the next person on this phone doesn't get your alerts.
  Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': FieldValue.delete()});
      await _fcm.deleteToken();
    } catch (_) {}
    _uid = null;
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'call') {
      _openIncomingCall(data);
      return;
    }
    if (data['type'] == 'message') {
      if (data['chatId'] == activeChatId) return;
      final n = message.notification;
      if (n == null) return;
      await _local.show(
        message.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'messages',
            'Messages',
            channelDescription: 'New message alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(data),
      );
    }
  }

  void _openFromData(Map<String, dynamic> data) {
    if (data['type'] == 'call') {
      _openIncomingCall(data);
    } else if (data['chatId'] != null) {
      _openChat(data);
    }
  }

  void _openChat(Map<String, dynamic> data) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    final chatId = data['chatId'] as String;
    final isGroup = data['isGroup'] == 'true';
    final senderUid = data['senderUid'] as String?;
    if (!isGroup && senderUid == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        otherUid: isGroup ? chatId : senderUid!,
        displayName: (data['title'] as String?) ?? 'Chat',
        isGroup: isGroup,
      ),
    ));
  }

  void _openIncomingCall(Map<String, dynamic> data) {
    final nav = appNavigatorKey.currentState;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (nav == null || myUid == null || _showingCall) return;
    _showingCall = true;
    final isGroup = data['isGroup'] == 'true';
    nav
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(
            chatId: data['chatId'] as String,
            myUid: myUid,
            callerName: (data['callerName'] as String?) ?? 'Someone',
            groupName: isGroup ? (data['groupName'] as String?) : null,
            video: data['video'] == 'true',
          ),
        ))
        .whenComplete(() => _showingCall = false);
  }
}

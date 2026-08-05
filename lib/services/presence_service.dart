import 'package:flutter/widgets.dart';
import 'firestore_service.dart';

/// Marks the user online while the app is in the foreground, and offline
/// (with a last-seen timestamp) when it's backgrounded or closed. Call
/// [start] once after login and [stop] on logout.
class PresenceService with WidgetsBindingObserver {
  final FirestoreService _firestoreService;
  String? _uid;

  PresenceService(this._firestoreService);

  void start(String uid) {
    _uid = uid;
    WidgetsBinding.instance.addObserver(this);
    _firestoreService.setOnline(uid, true);
  }

  void stop() {
    if (_uid != null) _firestoreService.setOnline(_uid!, false);
    WidgetsBinding.instance.removeObserver(this);
    _uid = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_uid == null) return;
    final online = state == AppLifecycleState.resumed;
    _firestoreService.setOnline(_uid!, online);
  }
}

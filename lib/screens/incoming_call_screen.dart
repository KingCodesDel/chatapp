import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/call_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_avatar.dart';
import 'call_screen.dart';

/// Full-screen "X is calling" with Accept / Decline. Rings (system sound +
/// vibration) until answered, declined, the call ends, or 45 seconds pass.
class IncomingCallScreen extends StatefulWidget {
  final String chatId;
  final String myUid;
  final String callerName;
  final String? groupName; // set for group calls
  final bool video;

  const IncomingCallScreen({
    super.key,
    required this.chatId,
    required this.myUid,
    required this.callerName,
    this.groupName,
    this.video = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _callService = CallService();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _ringTimer;
  Timer? _timeout;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _ring();
    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) => _ring());
    _timeout = Timer(const Duration(seconds: 45), _close);
    _sub = _callService.activeCallStream(widget.chatId, 'chats').listen((snap) {
      final d = snap.data();
      final active = d != null && d['active'] == true;
      if (!active && !_ended && mounted) {
        setState(() => _ended = true);
        _ringTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 1400), _close);
      }
    });
  }

  void _ring() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  void _close() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _accept() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CallScreen(
        chatOrRoomId: widget.chatId,
        collectionPath: 'chats',
        myUid: widget.myUid,
        startWithVideo: widget.video,
      ),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ringTimer?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Widget _round(IconData icon, Color color, String label, VoidCallback? onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _ended
        ? 'Call ended'
        : widget.groupName != null
            ? 'Group ${widget.video ? 'video' : 'voice'} call - ${widget.groupName}'
            : (widget.video ? 'Video call' : 'Voice call');
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.splashTop, AppColors.primaryDark, AppColors.splashBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              GradientAvatar(label: widget.callerName, size: 120),
              const SizedBox(height: 24),
              Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(flex: 3),
              if (!_ended)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _round(Icons.call_end_rounded, Colors.redAccent, 'Decline', _close),
                      _round(widget.video ? Icons.videocam_rounded : Icons.call_rounded, Colors.green, 'Accept', _accept),
                    ],
                  ),
                ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}

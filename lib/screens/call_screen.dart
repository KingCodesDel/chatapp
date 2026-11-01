import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../services/call_service.dart';
import '../services/push_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/gradient_avatar.dart';

/// Voice/video call screen backed by LiveKit. Works for both a 1:1 chat
/// call and a Conversation Room call — pass the right [collectionPath]
/// ('chats' or 'rooms') so call state is written to the right doc.
class CallScreen extends StatefulWidget {
  final String chatOrRoomId;
  final String collectionPath;
  final String myUid;
  final bool startWithVideo;

  const CallScreen({
    super.key,
    required this.chatOrRoomId,
    required this.collectionPath,
    required this.myUid,
    this.startWithVideo = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _callService = CallService();
  lk.Room? _room;
  bool _connecting = true;
  bool _micOn = true;
  bool _camOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _camOn = widget.startWithVideo;
    _join();
  }

  Future<void> _join() async {
    try {
      final wasActive = widget.collectionPath == 'chats'
          ? await _callService.isActive(widget.chatOrRoomId, widget.collectionPath)
          : true;
      final room = await _callService.startOrJoinCall(
        chatOrRoomId: widget.chatOrRoomId,
        uid: widget.myUid,
        collectionPath: widget.collectionPath,
      );
      await room.localParticipant?.setMicrophoneEnabled(_micOn);
      await room.localParticipant?.setCameraEnabled(_camOn);
      room.addListener(_onRoomUpdate);
      // First person in: ring everyone else in the chat.
      if (!wasActive) PushApi.notifyCall(widget.chatOrRoomId, video: widget.startWithVideo);
      if (!mounted) return;
      setState(() {
        _room = room;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not join the call: $e';
        _connecting = false;
      });
    }
  }

  void _onRoomUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _hangUp() async {
    await _callService.leaveCall(
      chatOrRoomId: widget.chatOrRoomId,
      uid: widget.myUid,
      collectionPath: widget.collectionPath,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsX.of(context);

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _connecting
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(child: _ParticipantGrid(room: _room!)),
                        _CallControls(
                          micOn: _micOn,
                          camOn: _camOn,
                          onToggleMic: () async {
                            _micOn = !_micOn;
                            await _room?.localParticipant?.setMicrophoneEnabled(_micOn);
                            setState(() {});
                          },
                          onToggleCam: () async {
                            _camOn = !_camOn;
                            await _room?.localParticipant?.setCameraEnabled(_camOn);
                            setState(() {});
                          },
                          onHangUp: _hangUp,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ParticipantGrid extends StatelessWidget {
  final lk.Room room;
  const _ParticipantGrid({required this.room});

  @override
  Widget build(BuildContext context) {
    final participants = <lk.Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return const Center(child: Text('Waiting for others to join…'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length <= 1 ? 1 : 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3 / 4,
      ),
      itemCount: participants.length,
      itemBuilder: (context, i) => _ParticipantTile(participant: participants[i]),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final lk.Participant participant;
  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.videoTrackPublications
        .where((p) => p.subscribed && p.track != null)
        .map((p) => p.track as lk.VideoTrack?)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        color: Colors.black87,
        child: videoTrack != null
            ? lk.VideoTrackRenderer(videoTrack)
            : Center(child: GradientAvatar(label: participant.identity, size: 64)),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  final bool micOn;
  final bool camOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;
  final VoidCallback onHangUp;

  const _CallControls({
    required this.micOn,
    required this.camOn,
    required this.onToggleMic,
    required this.onToggleCam,
    required this.onHangUp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(icon: micOn ? Icons.mic : Icons.mic_off, onTap: onToggleMic),
          const SizedBox(width: AppSpacing.md),
          _CircleButton(icon: camOn ? Icons.videocam : Icons.videocam_off, onTap: onToggleCam),
          const SizedBox(width: AppSpacing.md),
          _CircleButton(icon: Icons.call_end, onTap: onHangUp, color: Colors.redAccent),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _CircleButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

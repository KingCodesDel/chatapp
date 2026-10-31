import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../utils/media_utils.dart';

/// Full-screen player for a video message (tap the bubble to open).
class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Center(
        child: _failed
            ? const Text('Could not play this video', style: TextStyle(color: Colors.white70))
            : !_ready
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
                        if (!_c.value.isPlaying)
                          Container(
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(14),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                          ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 28,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VideoProgressIndicator(_c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.primary)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(formatDuration(_c.value.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(formatDuration(_c.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Video that plays inside the status viewer. Autoplays, tells the viewer when
/// it has finished so it can move on to the next status.
class StatusVideo extends StatefulWidget {
  final String url;
  final VoidCallback? onEnded;
  const StatusVideo({super.key, required this.url, this.onEnded});

  @override
  State<StatusVideo> createState() => _StatusVideoState();
}

class _StatusVideoState extends State<StatusVideo> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;
  bool _endedFired = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _c.addListener(_onTick);
  }

  void _onTick() {
    final v = _c.value;
    if (!_endedFired && v.isInitialized && v.duration > Duration.zero && v.position >= v.duration) {
      _endedFired = true;
      widget.onEnded?.call();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48));
    if (!_ready) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return Center(child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)));
  }
}

/// Plays a local file (used on the "add a caption" screen before posting).
class LocalVideoPreview extends StatefulWidget {
  final File file;
  const LocalVideoPreview({super.key, required this.file});

  @override
  State<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<LocalVideoPreview> {
  late final VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(widget.file);
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.setLooping(true);
      _c.play();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return GestureDetector(
      onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
      child: Center(child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))),
    );
  }
}

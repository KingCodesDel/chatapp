import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

final _urlPattern = RegExp(r'(https?:\/\/[^\s]+)');

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String type; // 'text' | 'image' | 'voice' | 'file' | 'poll'
  final String? imageUrl;
  final String status;
  final bool edited;
  final bool deleted;
  final String? senderName;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;

  // reply
  final String? replyToText;
  final String? replyToSender;

  // reactions
  final Map<String, String> reactions;
  final String currentUid;
  final void Function(String emoji)? onReactionTap;
  final bool isStarred;

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
  final Map<String, List<String>>? pollVotes;
  final void Function(int optionIndex)? onVote;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.type = 'text',
    this.imageUrl,
    this.status = 'sent',
    this.edited = false,
    this.deleted = false,
    this.senderName,
    this.onLongPress,
    this.onImageTap,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
    this.currentUid = '',
    this.onReactionTap,
    this.isStarred = false,
    this.audioUrl,
    this.audioSeconds,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes,
    this.onVote,
  });

  bool get _isMedia => type == 'image';

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(AppRadius.bubble);
    const tail = Radius.circular(AppRadius.bubbleTail);
    final shape = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isMe ? radius : tail,
      bottomRight: isMe ? tail : radius,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivedColor = isDark ? AppColors.bubbleReceivedDark : AppColors.bubbleReceived;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final showMediaBg = !deleted && _isMedia && imageUrl != null && imageUrl!.isNotEmpty;

    // Group reactions by emoji -> count, for a compact summary row.
    final reactionCounts = <String, int>{};
    for (final emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: (deleted || onLongPress == null) ? null : onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (senderName != null && !isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(senderName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              Container(
                decoration: BoxDecoration(color: showMediaBg ? Colors.transparent : (isMe ? AppColors.primary : receivedColor), borderRadius: shape),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (deleted)
                      _deletedContent(isMe)
                    else ...[
                      if (replyToText != null) _replyPreview(isMe, textPrimary),
                      _content(context, isMe, textPrimary),
                    ],
                    if (isMe && !deleted) _statusTick(showMediaBg),
                  ],
                ),
              ),
              if (reactionCounts.isNotEmpty) _reactionsRow(context, reactionCounts, isDark),
              if (isStarred)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deletedContent(bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 14, color: isMe ? Colors.white70 : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('Message deleted', style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _replyPreview(bool isMe, Color textPrimary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white : AppColors.primary).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: isMe ? Colors.white : AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replyToSender ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isMe ? Colors.white : AppColors.primary)),
          Text(replyToText ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: isMe ? Colors.white70 : textPrimary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, bool isMe, Color textPrimary) {
    switch (type) {
      case 'image':
        return GestureDetector(
          onTap: onImageTap,
          child: Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(height: 160, width: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
            },
            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 120, width: 160, child: Icon(Icons.broken_image_outlined)),
          ),
        );
      case 'voice':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _VoiceBubbleContent(url: audioUrl!, seconds: audioSeconds ?? 0, isMe: isMe),
        );
      case 'file':
        return InkWell(
          onTap: fileUrl == null ? null : () => launchUrl(Uri.parse(fileUrl!), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fileName ?? 'File', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white : textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (fileSize != null)
                        Text(_formatSize(fileSize!), style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case 'poll':
        return _pollContent(isMe, textPrimary);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: _linkedText(text, isMe, textPrimary),
        );
    }
  }

  Widget _linkedText(String value, bool isMe, Color textPrimary) {
    final baseStyle = TextStyle(color: isMe ? Colors.white : textPrimary, fontSize: 15, height: 1.35);
    final linkStyle = baseStyle.copyWith(color: isMe ? Colors.white : AppColors.primary, decoration: TextDecoration.underline);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _urlPattern.allMatches(value)) {
      if (match.start > last) spans.add(TextSpan(text: value.substring(last, match.start), style: baseStyle));
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
      last = match.end;
    }
    if (last < value.length) spans.add(TextSpan(text: value.substring(last), style: baseStyle));
    if (edited) {
      spans.add(TextSpan(text: '  (edited)', style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _pollContent(bool isMe, Color textPrimary) {
    final options = pollOptions ?? [];
    final votes = pollVotes ?? {};
    final totalVotes = votes.values.fold<int>(0, (sum, v) => sum + v.length);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pollQuestion ?? '', style: TextStyle(color: isMe ? Colors.white : textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++) ...[
            _pollOption(i, options[i], votes['$i'] ?? [], totalVotes, isMe),
            const SizedBox(height: 6),
          ],
          if (totalVotes > 0)
            Text('$totalVotes vote${totalVotes == 1 ? '' : 's'}', style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _pollOption(int index, String label, List<String> voters, int totalVotes, bool isMe) {
    final pct = totalVotes == 0 ? 0.0 : voters.length / totalVotes;
    final votedByMe = voters.contains(currentUid);
    final fillColor = isMe ? Colors.white.withValues(alpha: 0.28) : AppColors.primary.withValues(alpha: 0.18);
    final baseColor = isMe ? Colors.white.withValues(alpha: 0.14) : AppColors.divider;

    return InkWell(
      onTap: onVote == null ? null : () => onVote!(index),
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 34,
              color: baseColor,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: pct, alignment: Alignment.centerLeft, child: Container(color: fillColor)),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  if (votedByMe) Icon(Icons.check_circle_rounded, size: 14, color: isMe ? Colors.white : AppColors.primary),
                  if (votedByMe) const SizedBox(width: 5),
                  Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 13))),
                  if (totalVotes > 0) Text('${(pct * 100).round()}%', style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTick(bool showMediaBg) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 4, left: 10),
      child: Icon(
        status == 'read' ? Icons.done_all_rounded : Icons.done_rounded,
        size: 14,
        color: status == 'read' ? (showMediaBg ? AppColors.primary : Colors.white) : (showMediaBg ? AppColors.textSecondary : Colors.white70),
      ),
    );
  }

  Widget _reactionsRow(BuildContext context, Map<String, int> counts, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((e) {
          return GestureDetector(
            onTap: onReactionTap == null ? null : () => onReactionTap!(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _VoiceBubbleContent extends StatefulWidget {
  final String url;
  final int seconds;
  final bool isMe;
  const _VoiceBubbleContent({required this.url, required this.seconds, required this.isMe});

  @override
  State<_VoiceBubbleContent> createState() => _VoiceBubbleContentState();
}

class _VoiceBubbleContentState extends State<_VoiceBubbleContent> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.seconds);
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _toggle() async {
    if (!_playing) {
      if (_player.audioSource == null) await _player.setUrl(widget.url);
      _player.play();
    } else {
      _player.pause();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18)),
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Text(_fmt(_playing || _position.inSeconds > 0 ? _position : (_duration ?? Duration.zero)),
            style: TextStyle(color: widget.isMe ? Colors.white : AppColors.textPrimary, fontSize: 13)),
      ],
    );
  }
}

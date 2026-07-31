import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String type; // 'text' or 'image'
  final String? imageUrl;
  final String status; // 'sent' or 'read'
  final bool edited;
  final bool deleted;
  final String? senderName; // shown above the bubble in group chats
  final VoidCallback? onLongPress;

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
  });

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
    final isImage = !deleted && type == 'image' && imageUrl != null && imageUrl!.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: (deleted || onLongPress == null) ? null : onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (senderName != null && !isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(senderName!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              Container(
                decoration: BoxDecoration(
                  color: isImage ? Colors.transparent : (isMe ? AppColors.primary : receivedColor),
                  borderRadius: shape,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (deleted)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block_rounded, size: 14, color: isMe ? Colors.white70 : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('Message deleted',
                                style: TextStyle(
                                    color: isMe ? Colors.white70 : AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 14)),
                          ],
                        ),
                      )
                    else if (isImage)
                      Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                              height: 160, width: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(height: 120, width: 160, child: Icon(Icons.broken_image_outlined)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: text, style: TextStyle(color: isMe ? Colors.white : textPrimary, fontSize: 15, height: 1.35)),
                              if (edited)
                                TextSpan(
                                  text: '  (edited)',
                                  style: TextStyle(
                                      color: (isMe ? Colors.white70 : AppColors.textSecondary), fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (isMe && !deleted)
                      Padding(
                        padding: const EdgeInsets.only(right: 10, bottom: 4, left: 10),
                        child: Icon(
                          status == 'read' ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 14,
                          color: status == 'read' ? (isImage ? AppColors.primary : Colors.white) : (isImage ? AppColors.textSecondary : Colors.white70),
                        ),
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

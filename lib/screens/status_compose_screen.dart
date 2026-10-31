import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/video_widgets.dart';

/// Preview of the photo/video you picked, with a caption box.
/// Pops with the caption (possibly empty) when you tap Post, or null if you go back.
class StatusComposeScreen extends StatefulWidget {
  final File file;
  final bool isVideo;
  const StatusComposeScreen({super.key, required this.file, required this.isVideo});

  @override
  State<StatusComposeScreen> createState() => _StatusComposeScreenState();
}

class _StatusComposeScreenState extends State<StatusComposeScreen> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.isVideo ? 'Video status' : 'Photo status'),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.isVideo
                ? LocalVideoPreview(file: widget.file)
                : Center(child: Image.file(widget.file, fit: BoxFit.contain)),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 300,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.primary,
                    onPressed: () => Navigator.pop(context, _caption.text.trim()),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

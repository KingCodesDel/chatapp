import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/channel_service.dart';
import '../services/community_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/user_avatar.dart';
import 'channel_screen.dart';
import 'community_screen.dart';

/// One form for creating either a channel or a community.
class CreateSpaceScreen extends StatefulWidget {
  final bool community;
  const CreateSpaceScreen({super.key, required this.community});

  @override
  State<CreateSpaceScreen> createState() => _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends State<CreateSpaceScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _picker = ImagePicker();
  File? _photo;
  bool _saving = false;

  String get _kind => widget.community ? 'community' : 'channel';

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name (at least 3 characters)')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = AuthService().currentUser!.uid;
      var photoUrl = '';
      if (_photo != null) photoUrl = await StorageService().uploadGroupPhoto('space_$uid', _photo!);
      final String id;
      if (widget.community) {
        id = await CommunityService().create(ownerId: uid, name: _name.text, description: _desc.text, photoUrl: photoUrl);
      } else {
        id = await ChannelService().create(ownerId: uid, name: _name.text, description: _desc.text, photoUrl: photoUrl);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => widget.community ? CommunityScreen(communityId: id) : ChannelScreen(channelId: id),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create $_kind: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('New $_kind')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    _photo != null
                        ? ClipOval(child: Image.file(_photo!, width: 96, height: 96, fit: BoxFit.cover))
                        : UserAvatar(label: _name.text.isEmpty ? '?' : _name.text, size: 96),
                    const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _name, maxLength: 40, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Name your $_kind')),
            const SizedBox(height: AppSpacing.xs),
            TextField(controller: _desc, maxLength: 200, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.community
                  ? 'Communities have an announcement feed only you can post to, plus linked group chats people can join.'
                  : 'Channels are one-way: only you can post, and anyone can follow.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Create $_kind'),
            ),
          ],
        ),
      ),
    );
  }
}

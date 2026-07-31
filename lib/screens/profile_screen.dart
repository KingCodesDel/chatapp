import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _bioCtrl = TextEditingController();
  final _picker = ImagePicker();

  bool _uploadingPhoto = false;
  bool _savingBio = false;
  bool _bioLoaded = false;

  Future<void> _changePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final uid = _authService.currentUser!.uid;
      final url = await _storageService.uploadProfilePhoto(uid, File(picked.path));
      await _firestoreService.updateProfile(uid: uid, photoUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveBio() async {
    setState(() => _savingBio = true);
    try {
      final uid = _authService.currentUser!.uid;
      await _firestoreService.updateProfile(uid: uid, bio: _bioCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bio updated')));
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.userStream(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final user = AppUser.fromMap(snapshot.data!.data()!);
          if (!_bioLoaded) {
            _bioCtrl.text = user.bio;
            _bioLoaded = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Stack(
                  children: [
                    UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 104),
                    if (_uploadingPhoto)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4)),
                          child: const Center(
                              child: SizedBox(
                                  height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : _changePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(user.username, style: textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(user.email, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                Align(alignment: Alignment.centerLeft, child: Text('Bio', style: textTheme.titleMedium)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Add a short bio...'),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingBio ? null : _saveBio,
                    child: _savingBio
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save changes'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

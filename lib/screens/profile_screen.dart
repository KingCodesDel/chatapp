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
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();
  bool _uploadingPhoto = false;

  Future<void> _changePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid = _authService.currentUser!.uid;
      final url = await _storageService.uploadProfilePhoto(uid, File(picked.path));
      await _firestoreService.updateProfile(uid: uid, photoUrl: url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editProfile(String currentBio) async {
    final bioCtrl = TextEditingController(text: currentBio);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', hintText: 'A short line about you')),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _firestoreService.updateProfile(uid: _authService.currentUser!.uid, bio: bioCtrl.text);
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

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Stack(
                  children: [
                    UserAvatar(label: user.username, photoUrl: user.photoUrl, size: 128),
                    if (_uploadingPhoto)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4)),
                          child: const Center(
                              child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : _changePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(child: Text(user.username, style: textTheme.headlineSmall, textAlign: TextAlign.center)),
              const SizedBox(height: 2),
              Center(child: Text('@${user.username}', style: textTheme.bodyMedium?.copyWith(color: AppColors.primary))),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(child: Text(user.bio, style: textTheme.bodyMedium?.copyWith(color: AppColorsX.of(context).textSecondary), textAlign: TextAlign.center)),
              ],
              const SizedBox(height: AppSpacing.lg),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: Theme.of(context).dividerColor)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const _IconBadge(icon: Icons.edit_rounded),
                      title: const Text('Edit profile'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editProfile(user.bio),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const _IconBadge(icon: Icons.settings_outlined),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }
}

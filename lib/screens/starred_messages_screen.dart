import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final myUid = authService.currentUser!.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Starred messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestoreService.starredMessagesStream(myUid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Error loading starred messages:\n${snap.error}\n\nIf this mentions a missing index, tap the link in the error to create it (one-time setup).',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('No starred messages yet — long-press any message and tap Star to save it here.',
                    textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = data['type'] as String? ?? 'text';
              final preview = switch (type) {
                'image' => '📷 Photo',
                'voice' => '🎤 Voice message',
                'file' => '📎 ${data['fileName'] ?? 'File'}',
                'poll' => '📊 ${data['pollQuestion'] ?? 'Poll'}',
                _ => data['text'] as String? ?? '',
              };
              return Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

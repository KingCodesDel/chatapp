import 'package:flutter/material.dart';
import 'gradient_avatar.dart';

class UserAvatar extends StatelessWidget {
  final String label;
  final String? photoUrl;
  final double size;

  const UserAvatar({super.key, required this.label, this.photoUrl, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => GradientAvatar(label: label, size: size),
        ),
      );
    }
    return GradientAvatar(label: label, size: size);
  }
}

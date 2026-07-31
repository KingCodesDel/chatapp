import 'package:flutter/material.dart';

/// A circular avatar with a gradient derived from the person's name, so the
/// same person always gets the same colors without needing a photo.
class GradientAvatar extends StatelessWidget {
  final String label;
  final double size;

  const GradientAvatar({super.key, required this.label, this.size = 48});

  static const List<List<Color>> _palettes = [
    [Color(0xFF0E7C66), Color(0xFF16A085)], // teal
    [Color(0xFFFF6B4A), Color(0xFFFF9166)], // coral
    [Color(0xFF5B5FEF), Color(0xFF8B8FF5)], // periwinkle
    [Color(0xFFE0A83E), Color(0xFFF2C572)], // gold
    [Color(0xFF3E8FE0), Color(0xFF72B4F2)], // sky
  ];

  List<Color> get _gradient {
    if (label.isEmpty) return _palettes[0];
    final idx = label.codeUnitAt(0) % _palettes.length;
    return _palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

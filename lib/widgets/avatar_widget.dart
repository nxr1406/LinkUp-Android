import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AvatarWidget extends StatelessWidget {
  final UserModel? user;
  final double radius;

  const AvatarWidget({super.key, required this.user, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final photoBase64 = user?.photoBase64;

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
          backgroundColor: Colors.grey.shade200,
        );
      } catch (_) {}
    }

    // Fallback: colored circle with initial
    final name = user?.displayName ?? user?.username ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorFromString(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _colorFromString(String s) {
    const colors = [
      Color(0xFFE91E8C),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
      Color(0xFFE53935),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
      Color(0xFFF4511E),
      Color(0xFF3949AB),
    ];
    int hash = 0;
    for (final c in s.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFF;
    }
    return colors[hash % colors.length];
  }
}

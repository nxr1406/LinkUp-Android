import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double size;
  final bool showOnline;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.size = 44,
    this.showOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: AppColors.border,
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    ),
                  )
                : _placeholder(),
          ),
          if (showOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final initial = name?.isNotEmpty == true
        ? name![0].toUpperCase()
        : '?';
    return Text(
      initial,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

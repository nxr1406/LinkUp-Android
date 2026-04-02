import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarWidget extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const AvatarWidget({
    super.key,
    required this.url,
    required this.name,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFDBDBDB),
        child: url != null && url!.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _initials(),
                  errorWidget: (_, __, ___) => _initials(),
                ),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
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

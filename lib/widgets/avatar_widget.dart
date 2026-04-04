import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarWidget extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const AvatarWidget({super.key, required this.url, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty && url!.startsWith('http');
    return SizedBox(
      width: size, height: size,
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url!,
                width: size, height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      color: const Color(0xFFDBDBDB),
      child: Center(child: Text(initial,
          style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w600))),
    );
  }
}

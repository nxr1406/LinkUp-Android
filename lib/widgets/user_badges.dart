import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';

/// Shows verified (blue) and/or admin (golden) badge icons inline.
/// Use this widget everywhere a username is displayed.
///
///   Row(children: [
///     Text(user.username),
///     UserBadges(user: user, size: 14),
///   ])
class UserBadges extends StatelessWidget {
  final UserModel? user;
  final double size;
  final double spacing;

  const UserBadges({
    super.key,
    required this.user,
    this.size = 14,
    this.spacing = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    final badges = <Widget>[];

    // Verified badge: golden for admin, blue for regular verified
    if (user!.isAdmin) {
      badges.add(Icon(
        Icons.verified_rounded,
        color: const Color(0xFFFFB300),
        size: size,
      ));
    } else if (user!.isVerified) {
      badges.add(Icon(
        Icons.verified_rounded,
        color: AppColors.verified,
        size: size,
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: spacing),
        ...badges,
      ],
    );
  }
}

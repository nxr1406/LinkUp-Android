import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'chat_screen.dart';

class UserProfileViewScreen extends StatelessWidget {
  final UserModel user;
  const UserProfileViewScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final chatService = ChatService();
    final userService = UserService();
    const dark = false;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(dark),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ───────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.appBarBg(dark),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  color: AppColors.textPrimary(dark), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: AppColors.textPrimary(dark)),
                onSelected: (val) async {
                  if (val == 'block') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Block user?'),
                        content: Text(
                            "Block @${user.username}? They won't be able to message you."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Block',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(me.uid)
                          .update({
                        'blockedUsers': FieldValue.arrayUnion([user.uid])
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('@\${user.username} blocked'),
                          backgroundColor: Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                        ));
                        Navigator.pop(context);
                      }
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'block',
                    child: Row(children: const [
                      Icon(Icons.block, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Block', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.85),
                          AppColors.scaffoldBg(dark),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.scaffoldBg(dark), width: 4),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12),
                          ],
                        ),
                        child: AvatarWidget(user: user, radius: 52),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const SizedBox(height: 12),

                // Name + badge
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(user.displayName,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(dark))),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        color: AppColors.verified, size: 20),
                  ],
                ]),
                const SizedBox(height: 4),

                Text('@${user.username}',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(dark))),

                // Bio
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(user.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(dark),
                          height: 1.4)),
                ],

                const SizedBox(height: 20),

                // Stats row — live follower counts
                StreamBuilder<Map<String, int>>(
                  stream: userService.followCountsStream(user.uid),
                  builder: (context, snap) {
                    final counts = snap.data ?? {'followers': 0, 'following': 0};
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(dark),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                              value: '${counts['followers']}',
                              label: 'FOLLOWERS',
                              dark: dark),
                          Container(
                              width: 1,
                              height: 32,
                              color: AppColors.divider(dark)),
                          _StatItem(
                              value: '${counts['following']}',
                              label: 'FOLLOWING',
                              dark: dark),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final chatId =
                              chatService.getChatId(me.uid, user.uid);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                otherUser: user,
                                currentUid: me.uid,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Follow button (live state) ──────────────
                  Expanded(
                    child: StreamBuilder<bool>(
                      stream: userService.isFollowingStream(
                          followerId: me.uid, followingId: user.uid),
                      builder: (context, snap) {
                        final isFollowing = snap.data ?? false;
                        final isLoading =
                            snap.connectionState == ConnectionState.waiting;

                        return SizedBox(
                          height: 46,
                          child: isFollowing
                              ? OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => userService.unfollowUser(
                                          followerId: me.uid,
                                          followingId: user.uid),
                                  icon: Icon(Icons.person_remove_outlined,
                                      size: 18,
                                      color: AppColors.textPrimary(dark)),
                                  label: Text('Following',
                                      style: TextStyle(
                                          color: AppColors.textPrimary(dark),
                                          fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    side: BorderSide(
                                        color: AppColors.divider(dark)),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => userService.followUser(
                                          followerId: me.uid,
                                          followingId: user.uid),
                                  icon: const Icon(Icons.person_add_outlined,
                                      size: 18),
                                  label: const Text('Follow',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ]),

                // Suspended warning
                if (user.isSuspended) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.block, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('This account is suspended',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                    ]),
                  ),
                ],
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final bool dark;
  const _StatItem(
      {required this.value, required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(dark))),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(dark),
              letterSpacing: 0.5)),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(dark),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar with avatar ───────────────────────
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
              IconButton(
                icon: Icon(Icons.more_horiz,
                    color: AppColors.textPrimary(dark)),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
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
                  // Avatar centered
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body content ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Name + badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(dark)),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            color: AppColors.verified, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Username
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(dark)),
                  ),

                  // Bio
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(dark),
                          height: 1.4),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Stats row
                  Container(
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
                            value: '0',
                            label: 'FOLLOWERS',
                            dark: dark),
                        Container(
                            width: 1,
                            height: 32,
                            color: AppColors.divider(dark)),
                        _StatItem(
                            value: '0',
                            label: 'FOLLOWING',
                            dark: dark),
                      ],
                    ),
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
                          icon: const Icon(Icons.chat_bubble_outline,
                              size: 18),
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
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.person_add_outlined,
                              size: 18,
                              color: AppColors.textPrimary(dark)),
                          label: Text('Follow',
                              style: TextStyle(
                                  color: AppColors.textPrimary(dark))),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                                color: AppColors.divider(dark)),
                          ),
                        ),
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
                            style: TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
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

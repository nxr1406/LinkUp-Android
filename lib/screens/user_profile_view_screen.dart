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

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              user.username,
              style: const TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: AppColors.verified, size: 18),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          AvatarWidget(user: user, radius: 48),
          const SizedBox(height: 16),
          Text(
            user.displayName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.black),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('@${user.username}',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textMedium)),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified,
                    color: AppColors.verified, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  final chatId = chatService.getChatId(me.uid, user.uid);
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Send Message',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (user.isSuspended)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('This account is suspended',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

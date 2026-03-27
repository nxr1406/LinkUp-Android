import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../widgets/user_avatar.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (mounted && doc.exists) {
      setState(() {
        _user = UserModel.fromDoc(doc);
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat() async {
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final otherUserId = widget.userId;

    try {
      final existing = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String? chatId;
      for (final doc in existing.docs) {
        final parts = List<String>.from(doc.data()['participants'] ?? []);
        if (parts.contains(otherUserId)) {
          chatId = doc.id;
          break;
        }
      }

      chatId ??= (await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUser.uid: 0, otherUserId: 0},
        'typing': [],
        'createdAt': FieldValue.serverTimestamp(),
      }))
          .id;

      if (mounted) context.go('/chat/$chatId');
    } catch (e) {
      debugPrint('Error opening chat: $e');
    }
  }

  Future<void> _toggleBlock(ap.AuthProvider auth) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    final blocked = auth.userData?.blockedUsers.contains(widget.userId) ?? false;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'blockedUsers': blocked
            ? FieldValue.arrayRemove([widget.userId])
            : FieldValue.arrayUnion([widget.userId]),
      });

      _showSnack(blocked ? 'User unblocked' : 'User blocked', success: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ap.AuthProvider>(context);
    final isBlocked =
        auth.userData?.blockedUsers.contains(widget.userId) ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'block') _toggleBlock(auth);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Text(
                  isBlocked ? 'Unblock' : 'Block',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(
                  child: Text('User not found',
                      style: TextStyle(color: AppColors.subText)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      UserAvatar(
                        avatarUrl: _user!.avatarUrl,
                        name: _user!.fullName,
                        size: 112,
                        showOnline: _user!.isOnline,
                      ),
                      const SizedBox(height: 16),
                      Text(_user!.fullName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text('@${_user!.username}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.subText)),
                      if (_user!.bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_user!.bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.subText)),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Online status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _user!.isOnline
                                  ? AppColors.success
                                  : AppColors.border,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _user!.isOnline ? 'Active now' : 'Offline',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.subText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (!isBlocked)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ElevatedButton.icon(
                            onPressed: _openChat,
                            icon: const Icon(Icons.chat_bubble_outline,
                                size: 18),
                            label: const Text('Send Message'),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44)),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3F3),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.block, color: AppColors.error, size: 16),
                                SizedBox(width: 8),
                                Text('This user is blocked',
                                    style: TextStyle(
                                        color: AppColors.error, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

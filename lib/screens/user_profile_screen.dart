// user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (snap.exists) setState(() => _user = {'id': snap.id, ...snap.data()!});
    setState(() => _loading = false);
  }

  Future<void> _openChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    String? chatId;
    for (final doc in existing.docs) {
      final p = doc.data()['participants'] as List;
      if (p.contains(widget.userId)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final newChat =
          await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUser.uid, widget.userId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUser.uid: 0, widget.userId: 0},
      });
      chatId = newChat.id;
    }

    if (mounted) context.go('/chat/$chatId');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_user!['username'] ?? '')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarWidget(
                url: _user!['avatarUrl'],
                name: _user!['fullName'] ?? '',
                size: 80),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_user!['fullName'] ?? '',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              if (_user!['isVerified'] == true) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 18),
              ],
            ]),
            Text('@${_user!['username'] ?? ''}',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF8E8E8E))),
            if ((_user!['bio'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_user!['bio'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF262626))),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095F6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 10),
              ),
              child: const Text('Message',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

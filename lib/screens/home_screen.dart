import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedChatId;

  Future<Map<String, dynamic>?> _getOtherUser(
      List participants, String myId, bool isAdmin) async {
    final otherId =
        participants.firstWhere((id) => id != myId, orElse: () => null);
    if (otherId == null) return null;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherId)
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        if (data['isSuspended'] == true && !isAdmin) {
          return {
            'id': otherId,
            'fullName': 'LinkUp User',
            'username': 'linkup_user',
            'avatarUrl': null,
            'isDeleted': true,
          };
        }
        return {'id': otherId, ...data};
      }
    } catch (_) {}
    return null;
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return timeago.format(ts.toDate(), locale: 'en_short');
  }

  void _showActionSheet(String chatId) {
    setState(() => _selectedChatId = chatId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(
        onDelete: () async {
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .delete();
          if (mounted) Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<LinkUpAuthProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = auth.userData?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              auth.userData?['username'] ?? 'Messages',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF262626),
              ),
            ),
            if (auth.userData?['isVerified'] == true) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 18),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/app/search'),
            icon: const Icon(Icons.edit_outlined,
                size: 24, color: Color(0xFF262626)),
          ),
        ],
      ),
      body: currentUser == null
          ? const SizedBox()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants',
                      arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0095F6), strokeWidth: 2),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _EmptyState(
                      onTap: () => context.go('/app/search'));
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: Future.wait(
                    docs.map((doc) async {
                      final data = doc.data() as Map<String, dynamic>;
                      final otherUser = await _getOtherUser(
                          data['participants'] ?? [], currentUser.uid, isAdmin);
                      return {
                        'id': doc.id,
                        ...data,
                        'otherUser': otherUser,
                      };
                    }),
                  ),
                  builder: (context, chatsSnap) {
                    if (!chatsSnap.hasData) return const SizedBox();

                    final chats = chatsSnap.data!
                      ..sort((a, b) {
                        final ta =
                            (a['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ??
                                0;
                        final tb =
                            (b['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ??
                                0;
                        return tb.compareTo(ta);
                      });

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, i) {
                        final chat = chats[i];
                        final otherUser =
                            chat['otherUser'] as Map<String, dynamic>?;
                        final unreadCount =
                            (chat['unreadCount'] as Map?)?[currentUser.uid] ??
                                0;
                        final isUnread = unreadCount > 0;
                        final nickname =
                            (chat['nicknames'] as Map?)?[otherUser?['id']];
                        final displayName = nickname ??
                            otherUser?['username'] ??
                            'Unknown User';

                        return GestureDetector(
                          onLongPress: () => _showActionSheet(chat['id']),
                          onTap: () =>
                              context.go('/chat/${chat['id']}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Avatar with online indicator
                                Stack(
                                  children: [
                                    AvatarWidget(
                                      url: otherUser?['avatarUrl'],
                                      name: otherUser?['fullName'] ?? '',
                                      size: 44,
                                    ),
                                    if (otherUser?['isOnline'] == true)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0095F6),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                                color:
                                                    const Color(0xFF262626),
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (otherUser?['isVerified'] ==
                                              true) ...[
                                            const SizedBox(width: 4),
                                            const VerifiedBadge(size: 14),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${chat['lastMessageSenderId'] == currentUser.uid ? 'You: ' : ''}${chat['lastMessage'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isUnread
                                                    ? const Color(0xFF262626)
                                                    : const Color(
                                                        0xFF8E8E8E),
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ' · ${_formatTime(chat['lastMessageTime'] as Timestamp?)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF8E8E8E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0095F6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF262626), width: 2),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                size: 48, color: Color(0xFF262626)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF262626),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send private messages to a friend.',
            style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0095F6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('Send message',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  const _ActionSheet({required this.onDelete, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDBDBDB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Divider(height: 0),
          TextButton(
            onPressed: onDelete,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Delete Chat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFED4956),
                ),
              ),
            ),
          ),
          const Divider(height: 0),
          TextButton(
            onPressed: onCancel,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: 15, color: Color(0xFF262626)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

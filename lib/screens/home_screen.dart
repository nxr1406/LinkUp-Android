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
  Future<Map<String, dynamic>?> _getOtherUser(List participants, String myId, bool isAdmin) async {
    final otherId = participants.firstWhere((id) => id != myId, orElse: () => null);
    if (otherId == null) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
      if (snap.exists) {
        final data = snap.data()!;
        if (data['isSuspended'] == true && !isAdmin) {
          return {'id': otherId, 'fullName': 'LinkUp User', 'username': 'linkup_user', 'avatarUrl': null, 'isDeleted': true};
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

  void _showActionSheet(BuildContext context, String chatId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: divClr, borderRadius: BorderRadius.circular(2)))),
          Divider(height: 0, color: divClr),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Delete Chat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFED4956)))),
          ),
          Divider(height: 0, color: divClr),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Cancel', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : const Color(0xFF262626)))),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final auth = context.watch<LinkUpAuthProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = auth.userData?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(auth.userData?['username'] ?? 'Messages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary)),
          if (auth.userData?['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
        ]),
        actions: [
          IconButton(onPressed: () => context.go('/app/search'),
              icon: Icon(Icons.edit_outlined, size: 24, color: textPrimary)),
        ],
      ),
      body: currentUser == null ? const SizedBox() :
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('chats')
              .where('participants', arrayContains: currentUser.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return _EmptyState(onTap: () => context.go('/app/search'));

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: Future.wait(docs.map((doc) async {
                final data = doc.data() as Map<String, dynamic>;
                final otherUser = await _getOtherUser(data['participants'] ?? [], currentUser.uid, isAdmin);
                return {'id': doc.id, ...data, 'otherUser': otherUser};
              })),
              builder: (context, chatsSnap) {
                if (!chatsSnap.hasData) return const SizedBox();
                final chats = chatsSnap.data!
                  ..sort((a, b) {
                    final ta = (a['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final tb = (b['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return tb.compareTo(ta);
                  });

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final otherUser = chat['otherUser'] as Map<String, dynamic>?;
                    final unreadCount = (chat['unreadCount'] as Map?)?[currentUser.uid] ?? 0;
                    final isUnread = unreadCount > 0;
                    final nickname = (chat['nicknames'] as Map?)?[otherUser?['id']];
                    final displayName = nickname ?? otherUser?['username'] ?? 'Unknown User';

                    return GestureDetector(
                      onLongPress: () => _showActionSheet(context, chat['id']),
                      onTap: () => context.go('/chat/${chat['id']}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Stack(children: [
                            AvatarWidget(url: getAvatarUrl(otherUser), name: otherUser?['fullName'] ?? '', size: 44),
                            if (otherUser?['isOnline'] == true)
                              Positioned(bottom: 0, right: 0,
                                child: Container(width: 14, height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0095F6), shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2)))),
                          ]),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(displayName,
                                  style: TextStyle(fontSize: 14, fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400, color: textPrimary),
                                  overflow: TextOverflow.ellipsis)),
                              if (otherUser?['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 14)],
                            ]),
                            const SizedBox(height: 2),
                            Row(children: [
                              Expanded(child: Text(
                                '${chat['lastMessageSenderId'] == currentUser.uid ? 'You: ' : ''}${chat['lastMessage'] ?? ''}',
                                style: TextStyle(fontSize: 13,
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                    color: isUnread ? textPrimary : const Color(0xFF8E8E8E)),
                                overflow: TextOverflow.ellipsis)),
                              Text(' · ${_formatTime(chat['lastMessageTime'] as Timestamp?)}',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
                            ]),
                          ])),
                          if (isUnread)
                            Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(color: Color(0xFF0095F6), shape: BoxShape.circle)),
                        ]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 96, height: 96,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: textPrimary, width: 2)),
          child: Icon(Icons.chat_bubble_outline, size: 48, color: textPrimary)),
      const SizedBox(height: 16),
      Text('Your messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary)),
      const SizedBox(height: 8),
      const Text('Send private messages to a friend.', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0095F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
        child: const Text('Send message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]));
  }
}

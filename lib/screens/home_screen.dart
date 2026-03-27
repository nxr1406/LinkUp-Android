import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<UserModel> _activeUsers = [];
  List<Map<String, dynamic>> _chats = [];
  String? _selectedChatId;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<ap.AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final userData = authProvider.userData;

    if (currentUser == null) return const SizedBox();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    userData?.username ?? 'Messages',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 24, color: AppColors.text),
                    onPressed: () => context.go('/app/search'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Active users
                  SliverToBoxAdapter(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('isOnline', isEqualTo: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final users = snapshot.data!.docs
                            .map((d) => UserModel.fromDoc(d))
                            .where((u) =>
                                u.id != currentUser.uid &&
                                !(userData?.blockedUsers.contains(u.id) ??
                                    false))
                            .toList();
                        if (users.isEmpty) return const SizedBox();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Text(
                                'Active now',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text),
                              ),
                            ),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: users.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (_, i) {
                                  final u = users[i];
                                  return GestureDetector(
                                    onTap: () => context
                                        .go('/app/user/${u.id}'),
                                    child: Column(
                                      children: [
                                        UserAvatar(
                                          avatarUrl: u.avatarUrl,
                                          name: u.fullName,
                                          size: 60,
                                          showOnline: true,
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            u.username.length > 8
                                                ? '${u.username.substring(0, 8)}...'
                                                : u.username,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.subText),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(
                                height: 16,
                                color: AppColors.border,
                                thickness: 0.5),
                          ],
                        );
                      },
                    ),
                  ),
                  // Chat list
                  SliverToBoxAdapter(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .where('participants',
                              arrayContains: currentUser.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return _emptyState(context);
                        }
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _buildChatList(docs, currentUser.uid),
                          builder: (context, chatSnap) {
                            final chats = chatSnap.data ?? [];
                            if (chats.isEmpty && chatSnap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (chats.isEmpty) return _emptyState(context);
                            return Column(
                              children: chats.map((chat) {
                                return _chatTile(
                                    chat, currentUser.uid, context);
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buildChatList(
      List<QueryDocumentSnapshot> docs, String currentUid) async {
    final results = <Map<String, dynamic>>[];
    for (final d in docs) {
      final chat = ChatModel.fromDoc(d);
      final otherId =
          chat.participants.firstWhere((id) => id != currentUid, orElse: () => '');
      UserModel? otherUser;
      if (otherId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherId)
            .get();
        if (snap.exists) otherUser = UserModel.fromDoc(snap);
      }
      results.add({'chat': chat, 'otherUser': otherUser});
    }
    results.sort((a, b) {
      final tA = (a['chat'] as ChatModel).lastMessageTime?.millisecondsSinceEpoch ?? 0;
      final tB = (b['chat'] as ChatModel).lastMessageTime?.millisecondsSinceEpoch ?? 0;
      return tB.compareTo(tA);
    });
    return results;
  }

  Widget _chatTile(
      Map<String, dynamic> item, String currentUid, BuildContext context) {
    final chat = item['chat'] as ChatModel;
    final otherUser = item['otherUser'] as UserModel?;
    final unreadCount = chat.unreadCount[currentUid] ?? 0;
    final isUnread = unreadCount > 0;

    return GestureDetector(
      onTap: () => context.go('/chat/${chat.id}'),
      onLongPress: () => _showDeleteSheet(chat.id, context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: otherUser?.avatarUrl,
              name: otherUser?.fullName,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUser?.fullName ?? 'Unknown User',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: isUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: AppColors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessageSenderId == currentUid
                              ? 'You: ${chat.lastMessage}'
                              : chat.lastMessage,
                          style: TextStyle(
                              fontSize: 13,
                              color: isUnread
                                  ? AppColors.text
                                  : AppColors.subText,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ' · ${formatTimeAgo(chat.lastMessageTime)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.subText),
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
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteSheet(String chatId, BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              title: const Text('Delete Chat',
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .delete();
              },
            ),
            const Divider(height: 0, color: AppColors.border),
            ListTile(
              title: const Text('Cancel',
                  style: TextStyle(color: AppColors.text, fontSize: 15)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.text, width: 2),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 48, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            const Text('Your messages',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            const Text(
              'Send private messages to a friend.',
              style: TextStyle(fontSize: 14, color: AppColors.subText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/app/search'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 40)),
              child: const Text('Send message'),
            ),
          ],
        ),
      ),
    );
  }
}

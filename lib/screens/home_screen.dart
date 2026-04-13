import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'new_chat_screen.dart';
// ignore: unused_import
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _userService = UserService();
  final _authService = AuthService();
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService.setOnline(_currentUser.uid);
    // Mark all pending 'sent' messages as 'delivered' when app opens
    _chatService.markAllChatsDelivered(receiverUid: _currentUser.uid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService.setOffline(_currentUser.uid);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authService.setOnline(_currentUser.uid);
      // Re-mark delivered every time app comes to foreground
      _chatService.markAllChatsDelivered(receiverUid: _currentUser.uid);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _authService.setOffline(_currentUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _userService.userStream(_currentUser.uid),
      builder: (context, snapshot) {
        final me = snapshot.data;
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _ChatsTab(me: me),
              const SearchScreen(),
              ProfileScreen(me: me),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline, size: 26),
                activeIcon: Icon(Icons.chat_bubble, size: 26),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search, size: 26),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline, size: 26),
                activeIcon: Icon(Icons.person, size: 26),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatsTab extends StatefulWidget {
  final UserModel? me;
  const _ChatsTab({this.me});

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _chatService = ChatService();
  final _userService = UserService();

  // Cache user futures so FutureBuilder doesn't re-fetch on every rebuild
  final Map<String, Future<UserModel?>> _userFutureCache = {};

  Future<UserModel?> _getCachedUser(String uid) {
    return _userFutureCache.putIfAbsent(uid, () => _userService.getUser(uid));
  }

  // Track which chatIds we've already triggered markDelivered for in this session
  final Set<String> _deliveredChatIds = {};

  /// Called every time the chat list stream emits new data.
  /// For each chat that has unread messages (sent to me), mark them delivered.
  void _markChatsDelivered(List<ChatModel> chats) {
    for (final chat in chats) {
      // Only process chats where the OTHER person sent the last message
      // and there are unread messages for me — skip already processed ones
      final myUnread = chat.unreadCount[_currentUser.uid] ?? 0;
      final lastSenderIsOther =
          chat.lastMessageSenderId != null &&
          chat.lastMessageSenderId != _currentUser.uid;

      if (myUnread > 0 && lastSenderIsOther) {
        // Use chatId + lastMessageTime as key to avoid repeat calls
        final key = '${chat.id}_${chat.lastMessageTime?.millisecondsSinceEpoch}';
        if (!_deliveredChatIds.contains(key)) {
          _deliveredChatIds.add(key);
          _chatService.markDelivered(
            chatId: chat.id,
            receiverUid: _currentUser.uid,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          Text(
            widget.me?.username ?? 'LinkUp',
            style: TextStyle(
                color: AppColors.textPrimary(dark),
                fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
          if (widget.me?.isVerified == true) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: AppColors.verified, size: 18),
          ],
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square,
                color: AppColors.textPrimary(dark), size: 24),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NewChatScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatService.getUserChats(_currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final chats = snapshot.data ?? [];

          // ── Auto-mark delivered for all chats with new messages ──
          if (chats.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markChatsDelivered(chats);
            });
          }

          if (chats.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textSecondary(dark).withOpacity(0.4)),
                const SizedBox(height: 16),
                Text('No chats yet',
                    style: TextStyle(
                        color: AppColors.textSecondary(dark), fontSize: 16)),
                const SizedBox(height: 8),
                Text('Tap the edit icon to start chatting',
                    style: TextStyle(
                        color: AppColors.textSecondary(dark), fontSize: 13)),
              ]),
            );
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUid = chat.participants.firstWhere(
                  (id) => id != _currentUser.uid,
                  orElse: () => '');
              return FutureBuilder<UserModel?>(
                future: _getCachedUser(otherUid),
                builder: (context, userSnap) {
                  final other = userSnap.data;
                  final unread = chat.unreadCount[_currentUser.uid] ?? 0;
                  return _ChatTile(
                    chat: chat,
                    other: other,
                    currentUid: _currentUser.uid,
                    unreadCount: unread,
                    dark: dark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chat.id,
                          otherUser: other,
                          currentUid: _currentUser.uid,
                        ),
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

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final UserModel? other;
  final String currentUid;
  final int unreadCount;
  final bool dark;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat, required this.other, required this.currentUid,
    required this.unreadCount, required this.dark, required this.onTap,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = chat.lastMessageSenderId == currentUid;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AvatarWidget(user: other, radius: 26),
      title: Row(children: [
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                other?.username ?? '...',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary(dark)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (other?.isVerified == true) ...[
              const SizedBox(width: 3),
              const Icon(Icons.verified, color: AppColors.verified, size: 14),
            ],
          ]),
        ),
        Text(_formatTime(chat.lastMessageTime),
            style: TextStyle(
                color: AppColors.textSecondary(dark), fontSize: 12)),
      ]),
      subtitle: Row(children: [
        if (isMe)
          Text('You: ',
              style: TextStyle(
                  color: AppColors.textSecondary(dark), fontSize: 13)),
        Expanded(
          child: Text(
            chat.lastMessage ?? '',
            style: TextStyle(
              color: unreadCount > 0
                  ? AppColors.textPrimary(dark)
                  : AppColors.textSecondary(dark),
              fontSize: 13,
              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10)),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
      ]),
      onTap: onTap,
    );
  }
}

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

// ── Chats Tab ─────────────────────────────────────────────────────────────────
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

  final Map<String, Future<UserModel?>> _userFutureCache = {};
  Future<UserModel?> _getCachedUser(String uid) =>
      _userFutureCache.putIfAbsent(uid, () => _userService.getUser(uid));

  final Set<String> _deliveredChatIds = {};
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  void _toggleSelect(String id) =>
      setState(() => _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id));
  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _deleteSelected() async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF111111) : Colors.white,
        title: Text('Delete ${_selectedIds.length} chat${_selectedIds.length > 1 ? 's' : ''}?'),
        content: const Text('Chat history will be removed from your list only.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final chatId in List<String>.from(_selectedIds)) {
      await _chatService.deleteChat(chatId: chatId, userId: _currentUser.uid);
    }
    _clearSelection();
  }

  void _markChatsDelivered(List<ChatModel> chats) {
    for (final chat in chats) {
      final myUnread = chat.unreadCount[_currentUser.uid] ?? 0;
      final senderIsOther = chat.lastMessageSenderId != null &&
          chat.lastMessageSenderId != _currentUser.uid;
      if (myUnread > 0 && senderIsOther) {
        final key = '${chat.id}_${chat.lastMessageTime?.millisecondsSinceEpoch}';
        if (!_deliveredChatIds.contains(key)) {
          _deliveredChatIds.add(key);
          _chatService.markDelivered(chatId: chat.id, receiverUid: _currentUser.uid);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_isSelecting) { _clearSelection(); return false; }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg(dark),
        appBar: _isSelecting
            ? AppBar(
                backgroundColor: AppColors.appBarBg(dark),
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.close, color: AppColors.textPrimary(dark)),
                  onPressed: _clearSelection,
                ),
                title: Text(
                  '${_selectedIds.length} selected',
                  style: TextStyle(
                    color: AppColors.textPrimary(dark),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _deleteSelected,
                  ),
                ],
              )
            : AppBar(
                backgroundColor: AppColors.appBarBg(dark),
                elevation: 0,
                titleSpacing: 16,
                title: Row(children: [
                  Text(
                    widget.me?.username ?? 'LinkUp',
                    style: TextStyle(
                      color: AppColors.textPrimary(dark),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (widget.me?.isVerified == true) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified, color: AppColors.verified, size: 18),
                  ],
                ]),
                actions: [
                  // Camera icon (WhatsApp-style)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.textPrimary(dark),
                      size: 24,
                    ),
                    onPressed: () {},
                  ),
                  // Three-dot menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppColors.textPrimary(dark), size: 24),
                    color: dark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (value) {
                      if (value == 'new_chat') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NewChatScreen()));
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'new_chat',
                        child: Row(children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 18, color: AppColors.textPrimary(dark)),
                          const SizedBox(width: 12),
                          Text('New chat',
                              style: TextStyle(color: AppColors.textPrimary(dark))),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'new_group',
                        child: Row(children: [
                          Icon(Icons.group_add_outlined,
                              size: 18, color: AppColors.textPrimary(dark)),
                          const SizedBox(width: 12),
                          Text('New group',
                              style: TextStyle(color: AppColors.textPrimary(dark))),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Row(children: [
                          Icon(Icons.settings_outlined,
                              size: 18, color: AppColors.textPrimary(dark)),
                          const SizedBox(width: 12),
                          Text('Settings',
                              style: TextStyle(color: AppColors.textPrimary(dark))),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
        body: Column(
          children: [
            // ── WhatsApp-style Search Bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                child: AbsorbPointer(
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary(dark),
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary(dark),
                        size: 22,
                      ),
                      filled: true,
                      fillColor: dark
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF0F0F0),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Chat List ─────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<ChatModel>>(
                stream: _chatService.getUserChats(_currentUser.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  final chats = snapshot.data ?? [];
                  if (chats.isNotEmpty) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _markChatsDelivered(chats));
                  }
                  if (chats.isEmpty) {
                    return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64,
                                color: AppColors.textSecondary(dark).withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text('No chats yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary(dark), fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Tap + to start chatting',
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
                      final isSelected = _selectedIds.contains(chat.id);
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
                            isSelected: isSelected,
                            isSelecting: _isSelecting,
                            onTap: () {
                              if (_isSelecting) {
                                _toggleSelect(chat.id);
                              } else {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                          chatId: chat.id,
                                          otherUser: other,
                                          currentUid: _currentUser.uid),
                                    ));
                              }
                            },
                            onLongPress: () => _toggleSelect(chat.id),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // ── WhatsApp-style FAB ────────────────────────────────────────
        floatingActionButton: _isSelecting
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const NewChatScreen())),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 26),
              ),
      ),
    );
  }
}

// ── WhatsApp-style Chat Tile ──────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final UserModel? other;
  final String currentUid;
  final int unreadCount;
  final bool dark, isSelected, isSelecting;
  final VoidCallback onTap, onLongPress;

  const _ChatTile({
    required this.chat,
    required this.other,
    required this.currentUid,
    required this.unreadCount,
    required this.dark,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 24) {
      final h = t.hour, m = t.minute;
      final hh = h % 12 == 0 ? 12 : h % 12;
      return '$hh:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return d[t.weekday - 1];
    }
    return '${t.month}/${t.day}/${t.year % 100}';
  }

  Widget _tick(String? status) {
    if (status == null) return const SizedBox.shrink();
    final grey = dark ? Colors.white38 : Colors.grey.shade500;
    const cyan = Color(0xFF00BCD4);
    switch (status) {
      case 'sending':
        return SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: grey));
      case 'sent':
        return Icon(Icons.check, size: 16, color: grey);
      case 'delivered':
        return SizedBox(
            width: 22,
            child: Stack(children: [
              Icon(Icons.check, size: 16, color: grey),
              Positioned(left: 6, child: Icon(Icons.check, size: 16, color: grey)),
            ]));
      case 'seen':
        return SizedBox(
            width: 22,
            child: Stack(children: [
              const Icon(Icons.check, size: 16, color: cyan),
              Positioned(left: 6, child: const Icon(Icons.check, size: 16, color: cyan)),
            ]));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = chat.lastMessageSenderId == currentUid;
    final status = isMe ? chat.lastMessageStatus : null;
    final selBg = dark
        ? Colors.white.withOpacity(0.08)
        : AppColors.primary.withOpacity(0.08);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? selBg : Colors.transparent,
        // WhatsApp-style padding: more vertical breathing room
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar with selection overlay ─────────────────────────
            Stack(clipBehavior: Clip.none, children: [
              AvatarWidget(user: other, radius: 28), // slightly larger
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.88),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 22),
                  ),
                ),
            ]),
            const SizedBox(width: 14),

            // ── Text content ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name + Time
                  Row(
                    children: [
                      Expanded(
                        child: Row(children: [
                          Flexible(
                            child: Text(
                              other?.username ?? '...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: AppColors.textPrimary(dark),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (other?.isVerified == true) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.verified,
                                color: AppColors.verified, size: 14),
                          ],
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textSecondary(dark),
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Row 2: tick + preview + unread badge
                  Row(
                    children: [
                      if (isMe && status != null) ...[
                        _tick(status),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? '',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: unreadCount > 0
                                ? AppColors.textPrimary(dark)
                                : AppColors.textSecondary(dark),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

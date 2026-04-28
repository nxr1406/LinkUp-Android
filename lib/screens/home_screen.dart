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
import 'new_group_screen.dart';
// ignore: unused_import
import 'dart:async';

// ─── Filter tabs ──────────────────────────────────────────────────────────────
enum ChatFilter { all, unread, favorites, groups }

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
          backgroundColor: Colors.white,
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _ChatsTab(me: me),
              const SearchScreen(),
              ProfileScreen(me: me),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: const Color(0xFF9E9E9E),
              showSelectedLabels: false,
              showUnselectedLabels: false,
              elevation: 0,
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

  ChatFilter _filter = ChatFilter.all;

  final Map<String, Future<UserModel?>> _userFutureCache = {};
  Future<UserModel?> _getCachedUser(String uid) =>
      _userFutureCache.putIfAbsent(uid, () => _userService.getUser(uid));

  final Set<String> _deliveredChatIds = {};
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  // Favorites stored locally (can be persisted to Firestore later)
  final Set<String> _favoriteChatIds = {};

  void _toggleSelect(String id) => setState(
      () => _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id));
  void _clearSelection() => setState(() => _selectedIds.clear());

  void _toggleFavorite(String chatId) =>
      setState(() => _favoriteChatIds.contains(chatId)
          ? _favoriteChatIds.remove(chatId)
          : _favoriteChatIds.add(chatId));

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${_selectedIds.length} chat${_selectedIds.length > 1 ? 's' : ''}?'),
        content: const Text('Chat history will be removed from your list only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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

  // Apply active filter to chat list
  List<ChatModel> _applyFilter(List<ChatModel> chats) {
    switch (_filter) {
      case ChatFilter.all:
        return chats;
      case ChatFilter.unread:
        return chats
            .where((c) => (c.unreadCount[_currentUser.uid] ?? 0) > 0)
            .toList();
      case ChatFilter.favorites:
        return chats.where((c) => _favoriteChatIds.contains(c.id)).toList();
      case ChatFilter.groups:
        // Groups have more than 2 participants
        return chats.where((c) => c.participants.length > 2).toList();
    }
  }

  int _unreadCount(List<ChatModel> chats) =>
      chats.where((c) => (c.unreadCount[_currentUser.uid] ?? 0) > 0).length;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSelecting) {
          _clearSelection();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,

        // ── AppBar ──────────────────────────────────────────────
        appBar: _isSelecting
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF111111)),
                  onPressed: _clearSelection,
                ),
                title: Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                      color: Color(0xFF111111), fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _deleteSelected,
                  ),
                ],
              )
            : AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                titleSpacing: 16,
                title: Row(children: [
                  Text(
                    widget.me?.username ?? 'LinkUp',
                    style: const TextStyle(
                      color: Color(0xFF111111),
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
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF111111), size: 24),
                    onPressed: () {},
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFF111111), size: 24),
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'new_chat') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NewChatScreen()));
                      } else if (value == 'new_group') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NewGroupScreen()));
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'new_chat',
                        child: Row(children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 18, color: Color(0xFF111111)),
                          SizedBox(width: 12),
                          Text('New chat',
                              style: TextStyle(color: Color(0xFF111111), fontSize: 15)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'new_group',
                        child: Row(children: [
                          Icon(Icons.group_add_outlined,
                              size: 18, color: Color(0xFF111111)),
                          SizedBox(width: 12),
                          Text('New group',
                              style: TextStyle(color: Color(0xFF111111), fontSize: 15)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),

        body: StreamBuilder<List<ChatModel>>(
          stream: _chatService.getUserChats(_currentUser.uid),
          builder: (context, snapshot) {
            final allChats = snapshot.data ?? [];
            final totalUnread = _unreadCount(allChats);
            final filtered = _applyFilter(allChats);

            if (allChats.isNotEmpty) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _markChatsDelivered(allChats));
            }

            return Column(
              children: [
                // ── Search Bar ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SearchScreen())),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Row(children: [
                        SizedBox(width: 12),
                        Icon(Icons.search, color: Color(0xFF888888), size: 20),
                        SizedBox(width: 8),
                        Text('Search...',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 15,
                            )),
                      ]),
                    ),
                  ),
                ),

                // ── Filter Chips ───────────────────────────────
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _Chip(
                        label: 'All',
                        selected: _filter == ChatFilter.all,
                        onTap: () => setState(() => _filter = ChatFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Unread',
                        badge: totalUnread > 0 ? totalUnread : null,
                        selected: _filter == ChatFilter.unread,
                        onTap: () => setState(() => _filter = ChatFilter.unread),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Favorites',
                        selected: _filter == ChatFilter.favorites,
                        onTap: () => setState(() => _filter = ChatFilter.favorites),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Groups',
                        selected: _filter == ChatFilter.groups,
                        onTap: () => setState(() => _filter = ChatFilter.groups),
                      ),
                    ],
                  ),
                ),

                // thin divider
                const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),

                // ── Chat List ──────────────────────────────────
                Expanded(
                  child: _buildList(snapshot, filtered),
                ),
              ],
            );
          },
        ),

        // ── FAB ────────────────────────────────────────────────
        floatingActionButton: _isSelecting
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NewChatScreen())),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: const Icon(Icons.add_comment_outlined,
                    color: Colors.white, size: 26),
              ),
      ),
    );
  }

  Widget _buildList(AsyncSnapshot<List<ChatModel>> snapshot, List<ChatModel> filtered) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (filtered.isEmpty) {
      final isFiltered = _filter != ChatFilter.all;
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _filter == ChatFilter.unread
                ? Icons.mark_chat_read_outlined
                : _filter == ChatFilter.favorites
                    ? Icons.star_border_rounded
                    : _filter == ChatFilter.groups
                        ? Icons.group_outlined
                        : Icons.chat_bubble_outline,
            size: 60,
            color: const Color(0xFF9E9E9E).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No ${_filter.name} chats' : 'No chats yet',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? 'Try a different filter' : 'Tap + to start chatting',
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
          ),
        ]),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];
        final otherUid = chat.participants.firstWhere(
            (id) => id != _currentUser.uid,
            orElse: () => '');
        final isSelected = _selectedIds.contains(chat.id);
        final isFavorite = _favoriteChatIds.contains(chat.id);

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
              isSelected: isSelected,
              isSelecting: _isSelecting,
              isFavorite: isFavorite,
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
              onToggleFavorite: () => _toggleFavorite(chat.id),
            );
          },
        );
      },
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF444444),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (badge != null && badge! > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Chat Tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final UserModel? other;
  final String currentUid;
  final int unreadCount;
  final bool isSelected, isSelecting, isFavorite;
  final VoidCallback onTap, onLongPress, onToggleFavorite;

  const _ChatTile({
    required this.chat,
    required this.other,
    required this.currentUid,
    required this.unreadCount,
    required this.isSelected,
    required this.isSelecting,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
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
    const grey = Color(0xFFAAAAAA);
    const blue = Color(0xFF1A73E8);
    switch (status) {
      case 'sending':
        return const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: grey));
      case 'sent':
        return const Icon(Icons.check, size: 15, color: grey);
      case 'delivered':
        return SizedBox(width: 22, child: Stack(children: const [
          Icon(Icons.check, size: 15, color: grey),
          Positioned(left: 6, child: Icon(Icons.check, size: 15, color: grey)),
        ]));
      case 'seen':
        return SizedBox(width: 22, child: Stack(children: const [
          Icon(Icons.check, size: 15, color: blue),
          Positioned(left: 6, child: Icon(Icons.check, size: 15, color: blue)),
        ]));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = chat.lastMessageSenderId == currentUid;
    final status = isMe ? chat.lastMessageStatus : null;

    return Dismissible(
      key: Key('tile_${chat.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFFFF3CD),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: const Color(0xFFF59E0B),
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        onToggleFavorite();
        return false; // Don't actually dismiss
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // ── Avatar ────────────────────────────────────────
            Stack(clipBehavior: Clip.none, children: [
              AvatarWidget(user: other, radius: 27),
              if (isSelected)
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.88),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 22),
                )),
              // Favorite star badge
              if (isFavorite && !isSelected)
                Positioned(
                  bottom: 0, right: -2,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, color: Colors.white, size: 10),
                  ),
                ),
            ]),
            const SizedBox(width: 13),

            // ── Content ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Time
                  Row(children: [
                    Expanded(
                      child: Row(children: [
                        Flexible(
                          child: Text(
                            other?.username ?? '...',
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 15.5,
                              color: const Color(0xFF111111),
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
                        fontSize: 11.5,
                        color: unreadCount > 0
                            ? AppColors.primary
                            : const Color(0xFF9E9E9E),
                        fontWeight: unreadCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 3),

                  // Preview + Badge
                  Row(children: [
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
                              ? const Color(0xFF111111)
                              : const Color(0xFF888888),
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
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

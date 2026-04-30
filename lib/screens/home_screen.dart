import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/user_badges.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'new_chat_screen.dart';
import 'new_group_screen.dart';

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
              border: Border(
                  top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
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
                  icon: _NavIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    active: false,
                  ),
                  activeIcon: _NavIcon(
                    icon: Icons.chat_bubble_rounded,
                    active: true,
                  ),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: _NavIcon(icon: Icons.search_rounded, active: false),
                  activeIcon:
                      _NavIcon(icon: Icons.search_rounded, active: true),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: _NavIcon(
                      icon: Icons.person_outline_rounded, active: false),
                  activeIcon:
                      _NavIcon(icon: Icons.person_rounded, active: true),
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

// ── Modern nav icon ───────────────────────────────────────────────────────────
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _NavIcon({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 26,
        color: active ? AppColors.primary : const Color(0xFF9E9E9E));
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

  final Set<String> _favoriteChatIds = {};

  void _toggleSelect(String id) => setState(() =>
      _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id));
  void _clearSelection() => setState(() => _selectedIds.clear());
  void _toggleFavorite(String id) => setState(() =>
      _favoriteChatIds.contains(id)
          ? _favoriteChatIds.remove(id)
          : _favoriteChatIds.add(id));

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            'Delete ${_selectedIds.length} chat${_selectedIds.length > 1 ? 's' : ''}?'),
        content: const Text('Removed from your list only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
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
        final key =
            '${chat.id}_${chat.lastMessageTime?.millisecondsSinceEpoch}';
        if (!_deliveredChatIds.contains(key)) {
          _deliveredChatIds.add(key);
          _chatService.markDelivered(
              chatId: chat.id, receiverUid: _currentUser.uid);
        }
      }
    }
  }

  // Sort: pinned first, then by time
  List<ChatModel> _sortAndFilter(List<ChatModel> chats) {
    final uid = _currentUser.uid;

    // Apply filter
    List<ChatModel> filtered;
    switch (_filter) {
      case ChatFilter.all:
        filtered = chats;
        break;
      case ChatFilter.unread:
        filtered =
            chats.where((c) => (c.unreadCount[uid] ?? 0) > 0).toList();
        break;
      case ChatFilter.favorites:
        filtered =
            chats.where((c) => _favoriteChatIds.contains(c.id)).toList();
        break;
      case ChatFilter.groups:
        filtered = chats.where((c) => c.participants.length > 2).toList();
        break;
    }

    // Sort: pinned first
    filtered.sort((a, b) {
      final aPinned = a.pinnedBy.containsKey(uid);
      final bPinned = b.pinnedBy.containsKey(uid);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      final aTime = a.lastMessageTime ?? DateTime(0);
      final bTime = b.lastMessageTime ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  int _unreadCount(List<ChatModel> chats) =>
      chats.where((c) => (c.unreadCount[_currentUser.uid] ?? 0) > 0).length;

  // ── Long-press context menu ───────────────────────────────────────────────
  void _showChatContextMenu(
      BuildContext context, ChatModel chat, UserModel? other) {
    final uid = _currentUser.uid;
    final isPinned = chat.pinnedBy.containsKey(uid);
    final isUnread = (chat.unreadCount[uid] ?? 0) > 0;
    final isFav = _favoriteChatIds.contains(chat.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Chat preview header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                AvatarWidget(user: other, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chat.nicknames[other?.uid ?? '']?.isNotEmpty == true
                            ? chat.nicknames[other?.uid ?? '']!
                            : (other?.username ?? chat.id),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111111)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chat.nicknames[other?.uid ?? '']?.isNotEmpty == true)
                        Text(
                          other?.username ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9E9E9E)),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // Pin / Unpin
            _ContextTile(
              icon: isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded,
              label: isPinned ? 'Unpin chat' : 'Pin chat',
              iconColor: const Color(0xFF1A73E8),
              onTap: () {
                Navigator.pop(context);
                _chatService.pinChat(
                    chatId: chat.id, userId: uid, pin: !isPinned);
              },
            ),

            // Mark as read / unread
            _ContextTile(
              icon: isUnread
                  ? Icons.mark_chat_read_rounded
                  : Icons.mark_chat_unread_rounded,
              label: isUnread ? 'Mark as read' : 'Mark as unread',
              iconColor: const Color(0xFF1A73E8),
              onTap: () {
                Navigator.pop(context);
                if (isUnread) {
                  _chatService.markChatRead(
                      chatId: chat.id, userId: uid);
                } else {
                  _chatService.markChatUnread(
                      chatId: chat.id, userId: uid);
                }
              },
            ),

            // Favorite
            _ContextTile(
              icon: isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              label: isFav ? 'Remove from favorites' : 'Add to favorites',
              iconColor: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(chat.id);
              },
            ),

            // Delete
            _ContextTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete chat',
              iconColor: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete chat?'),
                    content: const Text(
                        'Removed from your list only.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style:
                                TextStyle(color: Color(0xFF666666))),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  _chatService.deleteChat(
                      chatId: chat.id, userId: uid);
                }
              },
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelecting) {
          _clearSelection();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _isSelecting
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF111111)),
                  onPressed: _clearSelection,
                ),
                title: Text('${_selectedIds.length} selected',
                    style: const TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
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
                        letterSpacing: 0.2),
                  ),
                  UserBadges(user: widget.me, size: 18),
                ]),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.photo_camera_outlined,
                        color: Color(0xFF111111), size: 24),
                    onPressed: () {},
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Color(0xFF111111), size: 24),
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'new_chat') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NewChatScreen()));
                      } else if (v == 'new_group') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NewGroupScreen()));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'new_chat',
                        child: Row(children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 18, color: Color(0xFF111111)),
                          SizedBox(width: 12),
                          Text('New chat',
                              style: TextStyle(
                                  color: Color(0xFF111111), fontSize: 15)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'new_group',
                        child: Row(children: [
                          Icon(Icons.group_add_rounded,
                              size: 18, color: Color(0xFF111111)),
                          SizedBox(width: 12),
                          Text('New group',
                              style: TextStyle(
                                  color: Color(0xFF111111), fontSize: 15)),
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
            final filtered = _sortAndFilter(allChats);

            if (allChats.isNotEmpty) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _markChatsDelivered(allChats));
            }

            return Column(children: [
              // ── Search Bar ───────────────────────────────────
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
                      Icon(Icons.search_rounded,
                          color: Color(0xFF888888), size: 20),
                      SizedBox(width: 8),
                      Text('Search...',
                          style: TextStyle(
                              color: Color(0xFF888888), fontSize: 15)),
                    ]),
                  ),
                ),
              ),

              // ── Filter Chips ─────────────────────────────────
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  children: [
                    _Chip(
                      label: 'All',
                      selected: _filter == ChatFilter.all,
                      onTap: () =>
                          setState(() => _filter = ChatFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Unread',
                      badge: totalUnread > 0 ? totalUnread : null,
                      selected: _filter == ChatFilter.unread,
                      onTap: () =>
                          setState(() => _filter = ChatFilter.unread),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Favorites',
                      selected: _filter == ChatFilter.favorites,
                      onTap: () =>
                          setState(() => _filter = ChatFilter.favorites),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Groups',
                      selected: _filter == ChatFilter.groups,
                      onTap: () =>
                          setState(() => _filter = ChatFilter.groups),
                    ),
                  ],
                ),
              ),

              const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFEEEEEE)),

              // ── Chat List ────────────────────────────────────
              Expanded(child: _buildList(snapshot, filtered)),
            ]);
          },
        ),

        floatingActionButton: _isSelecting
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NewChatScreen())),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 26),
              ),
      ),
    );
  }

  Widget _buildList(
      AsyncSnapshot<List<ChatModel>> snapshot, List<ChatModel> filtered) {
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
                ? Icons.mark_chat_read_rounded
                : _filter == ChatFilter.favorites
                    ? Icons.star_border_rounded
                    : _filter == ChatFilter.groups
                        ? Icons.group_outlined
                        : Icons.chat_bubble_outline_rounded,
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
        final uid = _currentUser.uid;
        final otherUid = chat.participants.firstWhere(
            (id) => id != uid, orElse: () => '');
        final isPinned = chat.pinnedBy.containsKey(uid);
        final isFav = _favoriteChatIds.contains(chat.id);
        final isSelected = _selectedIds.contains(chat.id);

        return FutureBuilder<UserModel?>(
          future: _getCachedUser(otherUid),
          builder: (context, userSnap) {
            final other = userSnap.data;
            final unread = chat.unreadCount[uid] ?? 0;
            // Get nickname for this user from chat data
            final otherNick = chat.nicknames[otherUid];

            return _ChatTile(
              chat: chat,
              other: other,
              currentUid: uid,
              unreadCount: unread,
              isSelected: isSelected,
              isSelecting: _isSelecting,
              isFavorite: isFav,
              isPinned: isPinned,
              nickname: otherNick?.isNotEmpty == true ? otherNick : null,
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
                            currentUid: uid),
                      ));
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showChatContextMenu(context, chat, other);
              },
            );
          },
        );
      },
    );
  }
}

// ── Context Menu Tile ─────────────────────────────────────────────────────────
class _ContextTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  const _ContextTile(
      {required this.icon,
      required this.label,
      required this.iconColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF111111),
              fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF444444),
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (badge != null && badge! > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white24
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
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
  final bool isSelected, isSelecting, isFavorite, isPinned;
  final VoidCallback onTap, onLongPress;
  final String? nickname; // nickname set for other user

  const _ChatTile({
    required this.chat,
    required this.other,
    required this.currentUid,
    required this.unreadCount,
    required this.isSelected,
    required this.isSelecting,
    required this.isFavorite,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
    this.nickname,
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
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: grey));
      case 'sent':
        return const Icon(Icons.check_rounded, size: 15, color: grey);
      case 'delivered':
        return SizedBox(
            width: 22,
            child: Stack(children: const [
              Icon(Icons.check_rounded, size: 15, color: grey),
              Positioned(
                  left: 6,
                  child: Icon(Icons.check_rounded, size: 15, color: grey)),
            ]));
      case 'seen':
        return SizedBox(
            width: 22,
            child: Stack(children: const [
              Icon(Icons.check_rounded, size: 15, color: blue),
              Positioned(
                  left: 6,
                  child:
                      Icon(Icons.check_rounded, size: 15, color: blue)),
            ]));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = chat.lastMessageSenderId == currentUid;
    final status = isMe ? chat.lastMessageStatus : null;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? AppColors.primary.withOpacity(0.08)
            : isPinned
                ? const Color(0xFFF8FAFF)
                : Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          // Avatar + selection + favorite badge
          Stack(clipBehavior: Clip.none, children: [
            AvatarWidget(user: other, radius: 27),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.88),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            if (isFavorite && !isSelected)
              Positioned(
                bottom: 0, right: -2,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 10),
                ),
              ),
          ]),
          const SizedBox(width: 13),

          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Row 1: Name + Pin icon + Time
              Row(children: [
                Expanded(
                  child: Row(children: [
                    if (isPinned) ...[
                      const Icon(Icons.push_pin_rounded,
                          size: 13, color: Color(0xFF1A73E8)),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nickname?.isNotEmpty == true
                                ? nickname!
                                : (other?.username ?? '...'),
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 15.5,
                              color: const Color(0xFF111111),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nickname?.isNotEmpty == true)
                            Text(
                              other?.username ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9E9E9E),
                                fontWeight: FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    UserBadges(user: other, size: 14),
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

              // Row 2: Tick + Preview + Badge
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
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

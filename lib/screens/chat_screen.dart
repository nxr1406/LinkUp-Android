import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _db = FirebaseFirestore.instance;
  final _me = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _otherUser;
  Map<String, dynamic>? _chatData;
  bool _loading = true;
  bool _showEmojiPicker = false;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _markAsRead();
  }

  Future<void> _loadChat() async {
    try {
      final chatSnap = await _db.collection('chats').doc(widget.chatId).get();
      if (!chatSnap.exists) return;
      final data = chatSnap.data()!;
      final otherId = (data['participants'] as List).firstWhere((id) => id != _me?.uid, orElse: () => null);
      if (otherId != null) {
        _db.collection('users').doc(otherId).snapshots().listen((snap) {
          if (mounted && snap.exists) setState(() => _otherUser = {'id': snap.id, ...snap.data()!});
        });
      }
      _db.collection('chats').doc(widget.chatId).snapshots().listen((snap) {
        if (mounted && snap.exists) setState(() => _chatData = snap.data());
      });
      setState(() => _loading = false);
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _markAsRead() async {
    if (_me == null) return;
    try {
      await _db.collection('chats').doc(widget.chatId).update({'unreadCount.${_me!.uid}': 0});
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _me == null) return;
    final reply = _replyingTo;
    _inputCtrl.clear();
    setState(() { _replyingTo = null; _showEmojiPicker = false; });
    try {
      await _db.collection('messages/${widget.chatId}/msgs').add({
        'content': text,
        'senderId': _me!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [_me!.uid],
        // শুধু id+senderId+content স্টোর করো - full snapshot নয়
        if (reply != null) 'replyTo': {
          'id': reply['id'],
          'senderId': reply['senderId'],
          'content': reply['content'] ?? '',
        },
      });
      await _db.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _me!.uid,
        'unreadCount.${_otherUser?['id']}': FieldValue.increment(1),
      });
      _scrollToBottom();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String _headerStatus() {
    if (_otherUser == null) return '';
    if (_otherUser!['isOnline'] == true) return 'Active now';
    final lastSeen = _otherUser!['lastSeen'] as Timestamp?;
    if (lastSeen == null) return '';
    return 'Active ${timeago.format(lastSeen.toDate())}';
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('EEE, MMM d').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF0095F6))));
    final isTyping = (_chatData?['typing'] as List?)?.contains(_otherUser?['id']) == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final inputPillColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF);
    final receivedBubbleColor = isDark ? const Color(0xFF262D35) : const Color(0xFFEFEFEF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final dividerColor = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => context.go('/app'),
          icon: Icon(Icons.arrow_back_ios, size: 20, color: textPrimary),
        ),
        title: GestureDetector(
          onTap: () { if (_otherUser?['id'] != null) context.go('/app/user/${_otherUser!['id']}'); },
          child: Row(children: [
            AvatarWidget(url: _otherUser?['avatarUrl'], name: _otherUser?['fullName'] ?? '', size: 32),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(
                  (_chatData?['nicknames'] as Map?)?[_otherUser?['id']] ?? _otherUser?['username'] ?? 'Unknown',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                if (_otherUser?['isVerified'] == true) ...[const SizedBox(width: 3), const VerifiedBadge(size: 13)],
              ]),
              Text(
                isTyping ? 'typing...' : _headerStatus(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E), fontWeight: FontWeight.w400),
              ),
            ])),
          ]),
        ),
        actions: [
          IconButton(
            onPressed: () => _showChatInfo(),
            icon: Icon(Icons.info_outline, color: textPrimary, size: 24),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: dividerColor),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('messages/${widget.chatId}/msgs').orderBy('createdAt').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              final docs = snap.data!.docs;
              final messages = docs.map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)}).where((m) {
                final deletedFor = (m['deletedFor'] as List?) ?? [];
                return !deletedFor.contains(_me?.uid);
              }).toList();
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              // Group by date
              List<dynamic> items = [];
              String? lastDate;
              for (final msg in messages) {
                final ts = msg['createdAt'] as Timestamp?;
                if (ts != null) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(ts.toDate());
                  if (dateStr != lastDate) {
                    items.add({'_type': 'header', 'date': ts.toDate()});
                    lastDate = dateStr;
                  }
                }
                items.add(msg);
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  if (item['_type'] == 'header') {
                    return _DateHeader(label: _formatDateHeader(item['date']));
                  }
                  final isMe = item['senderId'] == _me?.uid;
                  final isDeleted = item['deletedForEveryone'] == true || item['isDeleted'] == true;
                  final nextItem = i < items.length - 1 ? items[i + 1] : null;
                  final isLastMsg = nextItem == null || nextItem['_type'] == 'header' ||
                      (isMe && (nextItem['senderId'] != _me?.uid));
                  return _MessageBubble(
                    message: item,
                    isMe: isMe,
                    isDeleted: isDeleted,
                    otherUser: _otherUser,
                    isLastRead: isMe && isLastMsg,
                    chatId: widget.chatId,
                    onLongPress: () => _showMessageOptions(item),
                    onReply: () => setState(() => _replyingTo = item),
                  );
                },
              );
            },
          ),
        ),

        // Typing indicator
        if (isTyping)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(children: [
              AvatarWidget(url: _otherUser?['avatarUrl'], name: _otherUser?['fullName'] ?? '', size: 28),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: receivedBubbleColor, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  _BouncingDot(delay: 0),
                  const SizedBox(width: 3),
                  _BouncingDot(delay: 150),
                  const SizedBox(width: 3),
                  _BouncingDot(delay: 300),
                ]),
              ),
            ]),
          ),

        // Reply preview
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: dividerColor, width: 0.5)),
            ),
            child: Row(children: [
              Container(width: 3, height: 32, color: const Color(0xFF0095F6), margin: const EdgeInsets.only(right: 8)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Replying to ${_replyingTo!['senderId'] == _me?.uid ? 'yourself' : _otherUser?['fullName'] ?? 'user'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0095F6))),
                Text(_replyingTo!['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
              ])),
              IconButton(onPressed: () => setState(() => _replyingTo = null),
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF8E8E8E))),
            ]),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: surfaceColor,
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: inputPillColor, borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  if (_inputCtrl.text.isEmpty)
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        width: 32, height: 32,
                        decoration: const BoxDecoration(color: Color(0xFF0095F6), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _focusNode,
                      onTap: () => setState(() => _showEmojiPicker = false),
                      onChanged: (_) => setState(() {}),
                      maxLines: 4, minLines: 1,
                      style: TextStyle(fontSize: 15, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF8E8E8E)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  if (_inputCtrl.text.isEmpty) ...[
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.mic_none, color: textPrimary, size: 24),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      onPressed: () { setState(() => _showEmojiPicker = !_showEmojiPicker); if (_showEmojiPicker) _focusNode.unfocus(); },
                      icon: Icon(Icons.sentiment_satisfied_alt_outlined, color: textPrimary, size: 24),
                      padding: const EdgeInsets.all(8),
                    ),
                  ] else ...[
                    IconButton(
                      onPressed: () { setState(() => _showEmojiPicker = !_showEmojiPicker); if (_showEmojiPicker) _focusNode.unfocus(); },
                      icon: Icon(Icons.sentiment_satisfied_alt_outlined, color: textPrimary, size: 22),
                      padding: const EdgeInsets.all(6),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF0095F6), size: 24),
                      padding: const EdgeInsets.only(right: 8),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),

        if (_showEmojiPicker)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) { _inputCtrl.text += emoji.emoji; setState(() {}); },
              config: Config(
                height: 280,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  emojiSizeMax: 30,
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  recentsLimit: 28,
                ),
                skinToneConfig: const SkinToneConfig(
                  indicatorColor: Color(0xFF8E8E93),
                  dialogBackgroundColor: Color(0xFFF2F2F7),
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                  iconColor: const Color(0xFF8E8E93),
                  iconColorSelected: const Color(0xFF0095F6),
                  indicatorColor: const Color(0xFF0095F6),
                  initCategory: Category.RECENT,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  buttonIconColor: const Color(0xFF0095F6),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final isMe = msg['senderId'] == _me?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: dividerClr, borderRadius: BorderRadius.circular(2)))),
          // Emoji reactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((e) =>
                GestureDetector(
                  onTap: () { Navigator.pop(context); _addReaction(msg['id'], e); },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                )
              ).toList(),
            ),
          ),
          Divider(height: 0, color: dividerClr),
          _sheetBtn(Icons.reply_outlined, 'Reply', isDark ? Colors.white : const Color(0xFF262626), () {
            Navigator.pop(context);
            setState(() => _replyingTo = msg);
          }),
          Divider(height: 0, color: dividerClr, indent: 56),
          _sheetBtn(Icons.delete_outline, 'Delete for me', isDark ? Colors.white : const Color(0xFF262626), () {
            Navigator.pop(context);
            _db.collection('messages/${widget.chatId}/msgs').doc(msg['id'])
                .update({'deletedFor': FieldValue.arrayUnion([_me!.uid])});
          }),
          if (isMe) ...[
            Divider(height: 0, color: dividerClr, indent: 56),
            _sheetBtn(Icons.delete_sweep_outlined, 'Unsend', const Color(0xFFED4956), () {
              Navigator.pop(context);
              _db.collection('messages/${widget.chatId}/msgs').doc(msg['id'])
                  .update({'deletedForEveryone': true, 'content': ''});
            }),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sheetBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 24),
      title: Text(label, style: TextStyle(fontSize: 15, color: color)),
    );
  }

  void _showChatInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: dividerClr, borderRadius: BorderRadius.circular(2)))),
          _sheetBtn(Icons.cleaning_services_outlined, 'Clear Chat', const Color(0xFFED4956), () async {
            Navigator.pop(context);
            final q = await _db.collection('messages/${widget.chatId}/msgs').get();
            final batch = _db.batch();
            for (final d in q.docs) {
              batch.update(d.reference, {'deletedFor': FieldValue.arrayUnion([_me!.uid])});
            }
            await batch.commit();
          }),
          Divider(height: 0, color: dividerClr, indent: 56),
          _sheetBtn(Icons.delete_outline, 'Delete Chat', const Color(0xFFED4956), () async {
            Navigator.pop(context);
            await _db.collection('chats').doc(widget.chatId).delete();
            if (mounted) context.go('/app');
          }),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _addReaction(String msgId, String emoji) async {
    if (_me == null) return;
    final ref = _db.collection('messages/${widget.chatId}/msgs').doc(msgId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;

      // কে কোন emoji দিয়েছে সেটা track করা হয় userReactions-এ
      final userReactions = Map<String, dynamic>.from(
        (data['userReactions'] as Map?) ?? {},
      );

      final current = userReactions[_me!.uid];
      if (current == emoji) {
        // একই emoji আবার tap → remove (toggle off)
        userReactions.remove(_me!.uid);
      } else {
        // নতুন বা ভিন্ন emoji → set/change
        userReactions[_me!.uid] = emoji;
      }

      // count পুনরায় compute করো
      final reactions = <String, int>{};
      for (final r in userReactions.values) {
        final e = r as String;
        reactions[e] = (reactions[e] ?? 0) + 1;
      }

      tx.update(ref, {
        'userReactions': userReactions,
        if (reactions.isEmpty)
          'reactions': FieldValue.delete()
        else
          'reactions': reactions,
      });
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E), fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final int delay;
  const _BouncingDot({required this.delay});
  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF8E8E8E), shape: BoxShape.circle)),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDeleted;
  final bool isLastRead;
  final Map<String, dynamic>? otherUser;
  final String chatId;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDeleted,
    required this.isLastRead,
    required this.otherUser,
    required this.chatId,
    required this.onLongPress,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final replyTo = message['replyTo'] as Map?;
    final reactions = message['reactions'] as Map?;
    final readBy = (message['readBy'] as List?) ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivedBubble = isDark ? const Color(0xFF262D35) : const Color(0xFFEFEFEF);
    final receivedText = isDark ? Colors.white : const Color(0xFF262626);
    final deletedBorder = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    final reactionBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final reactionBorder = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: 2, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              AvatarWidget(
                  url: otherUser?['avatarUrl'],
                  name: otherUser?['fullName'] ?? '',
                  size: 28),
              const SizedBox(width: 6),
            ],
            Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65),
                  padding: isDeleted
                      ? const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10)
                      : const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? Colors.transparent
                        : isMe
                            ? const Color(0xFF0095F6)
                            : receivedBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 22),
                    ),
                    border:
                        isDeleted ? Border.all(color: deletedBorder) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live reply preview — unsend হলে automatically আপডেট হয়
                      if (replyTo != null)
                        _LiveReplyPreview(
                          replyTo: replyTo,
                          chatId: chatId,
                          isMe: isMe,
                        ),
                      // Message text
                      isDeleted
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.block,
                                  size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                'This message was unsent',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic),
                              ),
                            ])
                          : Text(
                              content,
                              style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      isMe ? Colors.white : receivedText),
                            ),
                    ],
                  ),
                ),
                // Reactions
                if (reactions != null && reactions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: reactionBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: reactionBorder),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions.entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(e.key,
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      if ((e.value as num).toInt() > 1) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          '${e.value}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? const Color(0xFFAEAEB2)
                                                : const Color(0xFF8E8E8E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ]),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              _ReadReceipt(
                  readBy: readBy,
                  otherUser: otherUser,
                  isPending: message['isPending'] == true),
            ],
          ],
        ),
      ),
    );
  }
}

// Unsend হওয়া message-এর reply preview live check করে
class _LiveReplyPreview extends StatelessWidget {
  final Map replyTo;
  final String chatId;
  final bool isMe;

  const _LiveReplyPreview({
    required this.replyTo,
    required this.chatId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final msgId = replyTo['id'] as String?;

    Widget box({required bool deleted, String content = ''}) {
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color:
                  isMe ? Colors.white : const Color(0xFF0095F6),
              width: 3,
            ),
          ),
        ),
        child: deleted
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.block,
                    size: 12,
                    color: isMe
                        ? Colors.white.withOpacity(0.55)
                        : Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'This message was unsent',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isMe
                        ? Colors.white.withOpacity(0.55)
                        : Colors.grey.shade400,
                  ),
                ),
              ])
            : Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe
                      ? Colors.white.withOpacity(0.8)
                      : const Color(0xFF8E8E8E),
                ),
              ),
      );
    }

    // id না থাকলে শুধু content দেখাও (backward compat)
    if (msgId == null) {
      return box(deleted: false, content: replyTo['content'] as String? ?? '');
    }

    // Live Firestore stream — original message unsent হলে instantly update
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages/$chatId/msgs')
          .doc(msgId)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          final isDeleted = data['deletedForEveryone'] == true ||
              data['isDeleted'] == true;
          if (isDeleted) return box(deleted: true);
          return box(
              deleted: false,
              content: data['content'] as String? ?? '');
        }
        // লোড হওয়ার আগে stored content দেখাও
        return box(
            deleted: false,
            content: replyTo['content'] as String? ?? '');
      },
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  final List readBy;
  final Map<String, dynamic>? otherUser;
  final bool isPending;
  const _ReadReceipt(
      {required this.readBy,
      required this.otherUser,
      required this.isPending});

  @override
  Widget build(BuildContext context) {
    if (isPending)
      return const SizedBox(
          width: 14,
          height: 14,
          child: CircleAvatar(backgroundColor: Color(0xFF8E8E8E)));
    final isRead =
        otherUser != null && readBy.contains(otherUser!['id']);
    if (isRead) {
      return SizedBox(
          width: 14,
          height: 14,
          child: AvatarWidget(
              url: otherUser!['avatarUrl'],
              name: otherUser!['fullName'] ?? '',
              size: 14));
    }
    return const Icon(Icons.check_circle,
        size: 14, color: Color(0xFF8E8E8E));
  }
}

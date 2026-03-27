import 'dart:async';
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

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;

  UserModel? _otherUser;
  bool _isTyping = false;
  MessageModel? _replyingTo;
  MessageModel? _selectedMessage;
  Timer? _typingTimer;

  StreamSubscription? _chatSub;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _initChat();
    _cleanupExpired();
    _markAsRead();
  }

  Future<void> _initChat() async {
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final chatDoc = await _db.collection('chats').doc(widget.chatId).get();
    if (!chatDoc.exists) return;

    final data = chatDoc.data()!;
    final otherId = (data['participants'] as List)
        .firstWhere((id) => id != currentUser.uid, orElse: () => '');

    if (otherId.isNotEmpty) {
      _chatSub = _db
          .collection('users')
          .doc(otherId)
          .snapshots()
          .listen((snap) {
        if (snap.exists && mounted) {
          setState(() => _otherUser = UserModel.fromDoc(snap));
        }
      });
    }

    // Listen typing
    _db.collection('chats').doc(widget.chatId).snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      final typing = List<String>.from(snap.data()?['typing'] ?? []);
      setState(() => _isTyping = typing.contains(otherId));
    });
  }

  Future<void> _cleanupExpired() async {
    try {
      final now = Timestamp.now();
      final snap = await _db
          .collection('messages')
          .doc(widget.chatId)
          .collection('msgs')
          .where('expiresAt', isLessThanOrEqualTo: now)
          .get();
      if (snap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  Future<void> _markAsRead() async {
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('chats')
          .doc(widget.chatId)
          .update({'unreadCount.$uid': 0});
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    _inputCtrl.clear();
    final replyRef = _replyingTo;
    setState(() => _replyingTo = null);

    final expiresAt =
        Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));

    try {
      await _db
          .collection('messages')
          .doc(widget.chatId)
          .collection('msgs')
          .add({
        'text': text,
        'senderId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
        'readBy': [uid],
        if (replyRef != null) 'replyToId': replyRef.id,
        if (replyRef != null) 'replyToText': replyRef.displayText,
      });

      await _db.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageSenderId': uid,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${_otherUser?.id}': FieldValue.increment(1),
        'typing': FieldValue.arrayRemove([uid]),
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  Future<void> _handleTyping(String val) async {
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    _typingTimer?.cancel();
    if (val.isNotEmpty) {
      await _db.collection('chats').doc(widget.chatId).update({
        'typing': FieldValue.arrayUnion([uid])
      });
      _typingTimer = Timer(const Duration(seconds: 3), () async {
        await _db.collection('chats').doc(widget.chatId).update({
          'typing': FieldValue.arrayRemove([uid])
        });
      });
    } else {
      await _db.collection('chats').doc(widget.chatId).update({
        'typing': FieldValue.arrayRemove([uid])
      });
    }
  }

  Future<void> _deleteMessage(String msgId) async {
    await _db
        .collection('messages')
        .doc(widget.chatId)
        .collection('msgs')
        .doc(msgId)
        .delete();
  }

  Future<void> _editMessage(MessageModel msg) async {
    final ctrl = TextEditingController(text: msg.displayText);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _db
          .collection('messages')
          .doc(widget.chatId)
          .collection('msgs')
          .doc(msg.id)
          .update({'editedText': result});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessageActions(MessageModel msg, String currentUid) {
    final isMine = msg.senderId == currentUid;
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
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
            ),
            if (isMine) ...[
              const Divider(height: 0, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(msg);
                },
              ),
              const Divider(height: 0, color: AppColors.border),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg.id);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ap.AuthProvider>(context);
    final currentUid = auth.currentUser?.uid ?? '';
    final isBlocked = auth.userData?.blockedUsers.contains(_otherUser?.id) ?? false;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        size: 20, color: AppColors.text),
                    onPressed: () => context.go('/app'),
                  ),
                  if (_otherUser != null)
                    GestureDetector(
                      onTap: () =>
                          context.go('/app/user/${_otherUser!.id}'),
                      child: Row(
                        children: [
                          UserAvatar(
                            avatarUrl: _otherUser!.avatarUrl,
                            name: _otherUser!.fullName,
                            size: 36,
                            showOnline: _otherUser!.isOnline,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_otherUser!.fullName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text)),
                              Text(
                                _isTyping
                                    ? 'typing...'
                                    : (_otherUser!.isOnline
                                        ? 'Active now'
                                        : 'Offline'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isTyping
                                      ? AppColors.primary
                                      : AppColors.subText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'delete') {
                        await _db
                            .collection('chats')
                            .doc(widget.chatId)
                            .delete();
                        if (mounted) context.go('/app');
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Chat',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('messages')
                    .doc(widget.chatId)
                    .collection('msgs')
                    .orderBy('createdAt', descending: false)
                    .snapshots(includeMetadataChanges: true),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final msgs = snap.data!.docs
                      .map((d) => MessageModel.fromDoc(d))
                      .toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.jumpTo(
                          _scrollCtrl.position.maxScrollExtent);
                    }
                  });

                  // Mark as read
                  _markAsRead();

                  if (msgs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 32, color: AppColors.border),
                          const SizedBox(height: 8),
                          Text(
                            'Messages disappear after 24 hours',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.subText),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final msg = msgs[i];
                      final isMine = msg.senderId == currentUid;
                      final showDate = i == 0 ||
                          _differentDay(
                              msgs[i - 1].createdAt, msg.createdAt);

                      return Column(
                        children: [
                          if (showDate) _dateHeader(msg.createdAt),
                          _messageBubble(msg, isMine, currentUid),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // Typing indicator
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('typing...',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.subText)),
                  ),
                ),
              ),
            // Reply preview
            if (_replyingTo != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF5F5F5),
                child: Row(
                  children: [
                    Container(
                        width: 3,
                        height: 36,
                        color: AppColors.primary,
                        margin: const EdgeInsets.only(right: 8)),
                    Expanded(
                      child: Text(
                        _replyingTo!.displayText,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.subText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.subText),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            // Input
            if (!isBlocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          controller: _inputCtrl,
                          onChanged: _handleTyping,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            border: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFFFF3F3),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, color: AppColors.error, size: 16),
                    SizedBox(width: 8),
                    Text('You have blocked this user',
                        style:
                            TextStyle(color: AppColors.error, fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(
      MessageModel msg, bool isMine, String currentUid) {
    final isRead = msg.readBy.length > 1;

    return GestureDetector(
      onLongPress: () => _showMessageActions(msg, currentUid),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Reply preview inside bubble
              if (msg.replyToText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFF007AE5)
                        : const Color(0xFFDEDEDE),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                        left: BorderSide(color: Colors.white70, width: 3)),
                  ),
                  child: Text(
                    msg.replyToText!,
                    style: TextStyle(
                        fontSize: 12,
                        color: isMine
                            ? Colors.white70
                            : AppColors.subText),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMine
                      ? AppColors.primary
                      : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomRight: isMine
                        ? const Radius.circular(4)
                        : const Radius.circular(18),
                    bottomLeft: isMine
                        ? const Radius.circular(18)
                        : const Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      msg.displayText,
                      style: TextStyle(
                          fontSize: 14,
                          color: isMine ? Colors.white : AppColors.text),
                    ),
                    if (msg.editedText != null)
                      Text(
                        'edited',
                        style: TextStyle(
                            fontSize: 10,
                            color: isMine
                                ? Colors.white60
                                : AppColors.subText),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatMessageTime(msg.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.subText),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead
                            ? AppColors.primary
                            : AppColors.subText,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateHeader(Timestamp? ts) {
    if (ts == null) return const SizedBox();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatDateHeader(ts.toDate()),
          style: const TextStyle(
              fontSize: 12, color: AppColors.subText),
        ),
      ),
    );
  }

  bool _differentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year ||
        da.month != db.month ||
        da.day != db.day;
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _chatSub?.cancel();
    _msgSub?.cancel();
    _typingTimer?.cancel();
    // Remove typing indicator on dispose
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      _db.collection('chats').doc(widget.chatId).update({
        'typing': FieldValue.arrayRemove([uid])
      }).catchError((_) {});
    }
    super.dispose();
  }
}

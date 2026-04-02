import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
  final _currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _otherUser;
  Map<String, dynamic>? _chatData;
  bool _loading = true;
  bool _showEmojiPicker = false;
  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _selectedMessage;
  bool _showActionSheet = false;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _markAsRead();
  }

  Future<void> _loadChat() async {
    try {
      final chatSnap =
          await _db.collection('chats').doc(widget.chatId).get();
      if (!chatSnap.exists) return;

      final data = chatSnap.data()!;
      final otherId = (data['participants'] as List)
          .firstWhere((id) => id != _currentUser?.uid, orElse: () => null);

      if (otherId != null) {
        _db.collection('users').doc(otherId).snapshots().listen((snap) {
          if (mounted && snap.exists) {
            setState(() => _otherUser = {'id': snap.id, ...snap.data()!});
          }
        });
      }

      _db
          .collection('chats')
          .doc(widget.chatId)
          .snapshots()
          .listen((snap) {
        if (mounted && snap.exists) {
          setState(() => _chatData = snap.data());
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead() async {
    if (_currentUser == null) return;
    try {
      await _db.collection('chats').doc(widget.chatId).update({
        'unreadCount.${_currentUser!.uid}': 0,
      });
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    final reply = _replyingTo;
    _inputCtrl.clear();
    setState(() => _replyingTo = null);

    try {
      final msgData = {
        'text': text,
        'senderId': _currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [_currentUser!.uid],
        if (reply != null) 'replyTo': reply,
      };

      await _db
          .collection('messages/${widget.chatId}/msgs')
          .add(msgData);

      await _db.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUser!.uid,
        'unreadCount.${_otherUser?['id']}':
            FieldValue.increment(1),
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> _deleteMessage(String msgId, {bool forEveryone = false}) async {
    try {
      if (forEveryone) {
        await _db
            .collection('messages/${widget.chatId}/msgs')
            .doc(msgId)
            .update({'deletedForEveryone': true, 'text': ''});
      } else {
        await _db
            .collection('messages/${widget.chatId}/msgs')
            .doc(msgId)
            .update({
          'deletedFor': FieldValue.arrayUnion([_currentUser!.uid])
        });
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return DateFormat('h:mm a').format(date);
    if (diff == 1) return 'Yesterday ${DateFormat('h:mm a').format(date)}';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF0095F6))),
      );
    }

    final isTyping = (_chatData?['typing'] as List?)
            ?.contains(_otherUser?['id']) ==
        true;
    final isBlocked = false; // Implement block check from userData

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => context.go('/app'),
          icon: const Icon(Icons.arrow_back_ios, size: 20),
        ),
        title: GestureDetector(
          onTap: () {
            if (_otherUser?['id'] != null) {
              context.go('/app/user/${_otherUser!['id']}');
            }
          },
          child: Row(
            children: [
              AvatarWidget(
                url: _otherUser?['avatarUrl'],
                name: _otherUser?['fullName'] ?? '',
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (_chatData?['nicknames'] as Map?)?[
                                  _otherUser?['id']] ??
                              _otherUser?['username'] ??
                              'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF262626),
                          ),
                        ),
                        if (_otherUser?['isVerified'] == true) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14),
                        ],
                      ],
                    ),
                    if (isTyping)
                      const Text('typing...',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF8E8E8E))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('messages/${widget.chatId}/msgs')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();

                final docs = snap.data!.docs;
                final messages = docs
                    .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
                    .where((m) {
                  final deletedFor = (m['deletedFor'] as List?) ?? [];
                  return !deletedFor.contains(_currentUser?.uid) &&
                      m['deletedForEveryone'] != true;
                }).toList();

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg['senderId'] == _currentUser?.uid;
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      formatTime: _formatMessageTime,
                      onReply: () =>
                          setState(() => _replyingTo = msg),
                      onDelete: () => _showDeleteOptions(msg),
                    );
                  },
                );
              },
            ),
          ),

          // Reply preview
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                border: Border(
                    top: BorderSide(color: Color(0xFFDBDBDB), width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    color: const Color(0xFF0095F6),
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Expanded(
                    child: Text(
                      _replyingTo?['text'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF262626)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFDBDBDB), width: 0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                    if (_showEmojiPicker) _focusNode.unfocus();
                  },
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: Color(0xFF8E8E8E)),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _focusNode,
                    onTap: () =>
                        setState(() => _showEmojiPicker = false),
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: const TextStyle(
                          fontSize: 14, color: Color(0xFF8E8E8E)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: Color(0xFFDBDBDB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: Color(0xFFDBDBDB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: Color(0xFFDBDBDB)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _inputCtrl.text.trim().isNotEmpty
                      ? _sendMessage
                      : null,
                  child: Icon(
                    Icons.send_rounded,
                    color: _inputCtrl.text.trim().isNotEmpty
                        ? const Color(0xFF0095F6)
                        : const Color(0xFFDBDBDB),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  _inputCtrl.text += emoji.emoji;
                  setState(() {});
                },
                config: const Config(
                  height: 250,
                  bgColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteOptions(Map<String, dynamic> msg) {
    final isMe = msg['senderId'] == _currentUser?.uid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            ListTile(
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
            ),
            if (isMe) ...[
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg['id'], forEveryone: true);
                },
                leading: const Icon(Icons.delete_forever,
                    color: Color(0xFFED4956)),
                title: const Text('Delete for everyone',
                    style: TextStyle(color: Color(0xFFED4956))),
              ),
            ],
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(msg['id']);
              },
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFED4956)),
              title: const Text('Delete for me',
                  style: TextStyle(color: Color(0xFFED4956))),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String Function(Timestamp?) formatTime;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.formatTime,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final replyTo = message['replyTo'] as Map?;
    final readBy = (message['readBy'] as List?) ?? [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return GestureDetector(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF0095F6)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply preview
                  if (replyTo != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF0095F6),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        replyTo['text'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF8E8E8E),
                        ),
                      ),
                    ),

                  // Message text
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : const Color(0xFF262626),
                    ),
                  ),

                  // Timestamp + read status
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTime(message['createdAt'] as Timestamp?),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF8E8E8E),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          readBy.length > 1
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: readBy.length > 1
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
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

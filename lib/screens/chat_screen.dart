import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'user_profile_view_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel? otherUser;
  final String currentUid;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
    required this.currentUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatService = ChatService();
  bool _sending = false;

  // Reply state
  MessageModel? _replyTo;

  // Typing debounce
  Timer? _typingTimer;
  bool _isTyping = false;

  // Scroll — track previous message count to scroll only on new messages
  int _prevMsgCount = 0;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _markRead();
    _markDelivered();
    _msgCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    if (!hasText) {
      // Field cleared — stop typing immediately
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        _chatService.setTyping(
            chatId: widget.chatId, uid: widget.currentUid, isTyping: false);
      }
      return;
    }
    // Start typing if not already
    if (!_isTyping) {
      _isTyping = true;
      _chatService.setTyping(
          chatId: widget.chatId, uid: widget.currentUid, isTyping: true);
    }
    // Reset inactivity timer — only fires if user STOPS typing for 3s
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        _chatService.setTyping(
            chatId: widget.chatId, uid: widget.currentUid, isTyping: false);
      }
    });
  }

  Future<void> _markRead() async {
    try {
      await _chatService.markMessagesRead(
          chatId: widget.chatId, userId: widget.currentUid);
    } catch (_) {}
  }

  Future<void> _markDelivered() async {
    try {
      await _chatService.markDelivered(
          chatId: widget.chatId, receiverUid: widget.currentUid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatService.setTyping(
        chatId: widget.chatId, uid: widget.currentUid, isTyping: false);
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending || widget.otherUser == null) return;

    final reply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    _msgCtrl.clear();
    _isTyping = false;
    _chatService.setTyping(
        chatId: widget.chatId, uid: widget.currentUid, isTyping: false);

    try {
      await _chatService.sendMessage(
        senderId: widget.currentUid,
        receiverId: widget.otherUser!.uid,
        text: text,
        replyToId: reply?.id,
        replyToText: reply?.text,
        replyToSender: reply?.senderId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      // Only auto-scroll if user is already near the bottom (within 200px)
      final nearBottom = pos.maxScrollExtent - pos.pixels < 200;
      if (nearBottom || !_initialScrollDone) {
        if (animate && _initialScrollDone) {
          _scrollCtrl.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(pos.maxScrollExtent);
          _initialScrollDone = true;
        }
      }
    });
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatDateHeader(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(time.year, time.month, time.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${time.day}/${time.month}/${time.year}';
  }

  void _showMessageOptions(MessageModel msg, bool isMe, ChatModel? chat) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(dark),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MessageOptionsSheet(
        msg: msg,
        isMe: isMe,
        dark: dark,
        chatId: widget.chatId,
        currentUid: widget.currentUid,
        otherUser: widget.otherUser,
        chatService: _chatService,
        onReply: () {
          setState(() => _replyTo = msg);
          Navigator.pop(context);
        },
        onForward: () {
          Navigator.pop(context);
          _forwardMessage(msg);
        },
      ),
    );
  }

  void _forwardMessage(MessageModel msg) {
    // Forward = resend same text with forwardedFrom flag
    if (widget.otherUser == null) return;
    _chatService.sendMessage(
      senderId: widget.currentUid,
      receiverId: widget.otherUser!.uid,
      text: msg.text,
      forwardedFrom: msg.senderId,
    );
  }

  void _showNicknameDialog(ChatModel? chat) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final otherNick = chat?.nicknames[widget.otherUser?.uid ?? ''] ?? '';
    final myNick = chat?.nicknames[widget.currentUid] ?? '';
    showDialog(
      context: context,
      builder: (_) => _NicknameDialog(
        dark: dark,
        chatId: widget.chatId,
        currentUid: widget.currentUid,
        otherUid: widget.otherUser?.uid ?? '',
        currentMyNick: myNick,
        currentOtherNick: otherNick,
        otherName: widget.otherUser?.displayName ?? '',
        chatService: _chatService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<ChatModel?>(
      stream: _chatService.chatStream(widget.chatId),
      builder: (context, chatSnap) {
        final chat = chatSnap.data;
        final otherNick = chat?.nicknames[widget.otherUser?.uid ?? ''];
        final isOtherTyping =
            chat?.typing[widget.otherUser?.uid ?? ''] == true;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  color: AppColors.textPrimary(dark), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: GestureDetector(
              onTap: () {
                if (widget.otherUser != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UserProfileViewScreen(
                              user: widget.otherUser!)));
                }
              },
              child: Row(children: [
                AvatarWidget(user: widget.otherUser, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            otherNick?.isNotEmpty == true
                                ? otherNick!
                                : (widget.otherUser?.displayName ?? '...'),
                            style: TextStyle(
                                color: AppColors.textPrimary(dark),
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          if (widget.otherUser?.isVerified == true) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.verified,
                                color: AppColors.verified, size: 14),
                          ],
                        ]),
                        isOtherTyping
                            ? Text('typing...',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic))
                            : _LastSeenText(
                                user: widget.otherUser, dark: dark),
                      ]),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_note,
                    color: AppColors.textPrimary(dark), size: 24),
                tooltip: 'Set Nickname',
                onPressed: () => _showNicknameDialog(chat),
              ),
              IconButton(
                icon: Icon(Icons.info_outline,
                    color: AppColors.textPrimary(dark)),
                onPressed: () {
                  if (widget.otherUser != null) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => UserProfileViewScreen(
                                user: widget.otherUser!)));
                  }
                },
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Text('Say hi! 👋',
                          style: TextStyle(
                              color: AppColors.textSecondary(dark),
                              fontSize: 16)),
                    );
                  }

                  // Scroll only when message count increases (new message arrived)
                  // or on first load — NOT on every typing/chat stream update
                  if (!_initialScrollDone || messages.length > _prevMsgCount) {
                    _prevMsgCount = messages.length;
                    _scrollToBottom(animate: _initialScrollDone);
                  }

                  // Seen status: last message seen by other
                  final otherSeenAt =
                      chat?.seenBy[widget.otherUser?.uid ?? ''];

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == widget.currentUid;
                      final showDate = index == 0 ||
                          _formatDateHeader(msg.timestamp) !=
                              _formatDateHeader(
                                  messages[index - 1].timestamp);

                      // isLastMyMsg: this is the last message sent by ME in the list
                      final isLastMyMsg = isMe && (
                          index == messages.length - 1 ||
                          messages.sublist(index + 1)
                              .every((m) => m.senderId != widget.currentUid)
                      );
                      final showSeen = isLastMyMsg &&
                          otherSeenAt != null &&
                          otherSeenAt.isAfter(msg.timestamp);

                      return Column(children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatDateHeader(msg.timestamp),
                              style: TextStyle(
                                  color: AppColors.textSecondary(dark),
                                  fontSize: 11),
                            ),
                          ),
                        _SwipeableMessage(
                          key: ValueKey(msg.id),
                          isMe: isMe,
                          onSwipe: () =>
                              setState(() => _replyTo = msg),
                          child: _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            time: _formatTime(msg.timestamp),
                            dark: dark,
                            showSeen: showSeen,
                            currentUid: widget.currentUid,
                            chatId: widget.chatId,
                            chatService: _chatService,
                            otherUser: widget.otherUser,
                            myNick: chat?.nicknames[widget.currentUid],
                            otherNick: chat?.nicknames[
                                widget.otherUser?.uid ?? ''],
                            onLongPress: msg.isUnsent
                                ? null
                                : () => _showMessageOptions(
                                    msg, isMe, chat),
                          ),
                        ),
                      ]);
                    },
                  );
                },
              ),
            ),
            // Reply preview bar
            if (_replyTo != null)
              _ReplyBar(
                msg: _replyTo!,
                isMe: _replyTo!.senderId == widget.currentUid,
                dark: dark,
                onCancel: () => setState(() => _replyTo = null),
              ),
            _buildInputBar(dark),
          ]),
        );
      },
    );
  }

  Widget _buildInputBar(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.appBarBg(dark),
        border: Border(top: BorderSide(color: AppColors.divider(dark))),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child:
              const Icon(Icons.camera_alt, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill(dark),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider(dark)),
            ),
            child: TextField(
              controller: _msgCtrl,
              style: TextStyle(
                  fontSize: 15, color: AppColors.textPrimary(dark)),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _msgCtrl,
          builder: (_, value, __) {
            final hasText = value.text.trim().isNotEmpty;
            return GestureDetector(
              onTap: hasText ? _sendMessage : null,
              child: Icon(
                hasText ? Icons.send : Icons.mic_none,
                color: hasText
                    ? AppColors.primary
                    : AppColors.textSecondary(dark),
                size: 26,
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        Icon(Icons.sentiment_satisfied_alt_outlined,
            color: AppColors.textSecondary(dark), size: 26),
      ]),
    );
  }
}

// ── Swipeable message wrapper ─────────────────────────────────────────────────
class _SwipeableMessage extends StatefulWidget {
  final bool isMe;
  final Widget child;
  final VoidCallback onSwipe;

  const _SwipeableMessage({
    super.key,
    required this.isMe,
    required this.child,
    required this.onSwipe,
  });

  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        // isMe (my msg) → swipe RIGHT (positive drag) to reply
        // other's msg → swipe LEFT (negative drag) to reply
        final delta = d.delta.dx;
        if (widget.isMe && delta < 0) {
          setState(() => _drag = (_drag + delta).clamp(-60.0, 0.0));
        } else if (!widget.isMe && delta > 0) {
          setState(() => _drag = (_drag + delta).clamp(0.0, 60.0));
        }
      },
      onHorizontalDragEnd: (_) {
        if (_drag.abs() >= 40) widget.onSwipe();
        setState(() => _drag = 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(_drag, 0, 0),
        child: widget.child,
      ),
    );
  }
}

// ── Reply preview bar ─────────────────────────────────────────────────────────
class _ReplyBar extends StatelessWidget {
  final MessageModel msg;
  final bool isMe, dark;
  final VoidCallback onCancel;

  const _ReplyBar({
    required this.msg,
    required this.isMe,
    required this.dark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill(dark),
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.4)),
          left: const BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? 'You' : 'Them',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              Text(
                msg.isUnsent ? 'Message was unsent' : msg.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textSecondary(dark), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: AppColors.textSecondary(dark)),
          onPressed: onCancel,
        ),
      ]),
    );
  }
}

// ── Message options bottom sheet ──────────────────────────────────────────────
class _MessageOptionsSheet extends StatelessWidget {
  final MessageModel msg;
  final bool isMe, dark;
  final String chatId, currentUid;
  final UserModel? otherUser;
  final ChatService chatService;
  final VoidCallback onReply;
  final VoidCallback onForward;

  const _MessageOptionsSheet({
    required this.msg,
    required this.isMe,
    required this.dark,
    required this.chatId,
    required this.currentUid,
    required this.otherUser,
    required this.chatService,
    required this.onReply,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.divider(dark),
              borderRadius: BorderRadius.circular(2)),
        ),
        // Reaction row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((e) {
              return GestureDetector(
                onTap: () {
                  chatService.toggleReaction(
                    chatId: chatId,
                    messageId: msg.id,
                    emoji: e,
                    uid: currentUid,
                  );
                  Navigator.pop(context);
                },
                child: Text(e, style: const TextStyle(fontSize: 28)),
              );
            }).toList(),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.reply),
          title: const Text('Reply'),
          onTap: onReply,
        ),
        ListTile(
          leading: const Icon(Icons.forward),
          title: const Text('Forward'),
          onTap: onForward,
        ),
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copy'),
          onTap: () {
            Clipboard.setData(ClipboardData(text: msg.text));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Copied'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating),
            );
          },
        ),
        if (isMe && !msg.isUnsent) ...[
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _showEditDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline,
                color: Colors.orange),
            title: const Text('Unsend',
                style: TextStyle(color: Colors.orange)),
            onTap: () {
              Navigator.pop(context);
              chatService.unsentMessage(
                  chatId: chatId, messageId: msg.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title:
                const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              chatService.deleteMessage(
                  chatId: chatId, messageId: msg.id);
            },
          ),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          minLines: 1,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              chatService.editMessage(
                  chatId: chatId,
                  messageId: msg.id,
                  newText: ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Nickname dialog ────────────────────────────────────────────────────────────
class _NicknameDialog extends StatefulWidget {
  final bool dark;
  final String chatId, currentUid, otherUid;
  final String currentMyNick, currentOtherNick, otherName;
  final ChatService chatService;

  const _NicknameDialog({
    required this.dark,
    required this.chatId,
    required this.currentUid,
    required this.otherUid,
    required this.currentMyNick,
    required this.currentOtherNick,
    required this.otherName,
    required this.chatService,
  });

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _myCtrl;
  late final TextEditingController _otherCtrl;

  @override
  void initState() {
    super.initState();
    _myCtrl = TextEditingController(text: widget.currentMyNick);
    _otherCtrl = TextEditingController(text: widget.currentOtherNick);
  }

  @override
  void dispose() {
    _myCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg(widget.dark),
      title: Text('Nicknames',
          style: TextStyle(color: AppColors.textPrimary(widget.dark))),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _myCtrl,
          style: TextStyle(color: AppColors.textPrimary(widget.dark)),
          decoration: InputDecoration(
            labelText: 'Your nickname',
            labelStyle: TextStyle(color: AppColors.textSecondary(widget.dark)),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _otherCtrl,
          style: TextStyle(color: AppColors.textPrimary(widget.dark)),
          decoration: InputDecoration(
            labelText: '${widget.otherName}\'s nickname',
            labelStyle: TextStyle(color: AppColors.textSecondary(widget.dark)),
            border: const OutlineInputBorder(),
          ),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            await widget.chatService
                .setNickname(
                    chatId: widget.chatId,
                    targetUid: widget.currentUid,
                    nickname: _myCtrl.text.trim())
                .catchError((_) {});
            await widget.chatService
                .setNickname(
                    chatId: widget.chatId,
                    targetUid: widget.otherUid,
                    nickname: _otherCtrl.text.trim())
                .catchError((_) {});
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Last seen text ─────────────────────────────────────────────────────────────
class _LastSeenText extends StatelessWidget {
  final UserModel? user;
  final bool dark;
  const _LastSeenText({required this.user, required this.dark});

  @override
  Widget build(BuildContext context) {
    final lastSeen = user?.lastSeen;
    if (lastSeen == null) return const SizedBox.shrink();
    final diff = DateTime.now().difference(lastSeen);
    String status;
    if (diff.inMinutes < 5) {
      status = 'Active now';
    } else if (diff.inMinutes < 60) {
      status = 'Active ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      status = 'Active ${diff.inHours}h ago';
    } else {
      status = 'Active ${diff.inDays}d ago';
    }
    return Text(status,
        style: TextStyle(color: AppColors.textSecondary(dark), fontSize: 11));
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe, dark;
  final String time, chatId, currentUid;
  final bool showSeen;
  final ChatService chatService;
  final String? myNick, otherNick;
  final VoidCallback? onLongPress;
  final UserModel? otherUser;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    required this.dark,
    required this.showSeen,
    required this.chatId,
    required this.currentUid,
    required this.chatService,
    this.myNick,
    this.otherNick,
    this.onLongPress,
    this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUnsent) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            'Message was unsent',
            style: TextStyle(
                color: AppColors.textSecondary(dark),
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final hasReactions = message.reactions.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Forwarded label
          if (message.forwardedFrom != null)
            Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 0 : 12, right: isMe ? 12 : 0, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forward,
                      size: 12, color: AppColors.textSecondary(dark)),
                  const SizedBox(width: 2),
                  Text('Forwarded',
                      style: TextStyle(
                          color: AppColors.textSecondary(dark),
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),

          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              margin: EdgeInsets.only(
                  top: 3,
                  bottom: hasReactions ? 0 : 3,
                  left: isMe ? 60 : 0,
                  right: isMe ? 0 : 60),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.messageBubble
                    : AppColors.bubbleOther(dark),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Reply preview inside bubble
                  if (message.replyToText != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                            left: const BorderSide(
                                color: AppColors.primary, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToSender == currentUid
                                ? (myNick?.isNotEmpty == true
                                    ? myNick!
                                    : 'You')
                                : (otherNick?.isNotEmpty == true
                                    ? otherNick!
                                    : 'Them'),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            message.replyToText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe
                                  ? Colors.white.withOpacity(0.85)
                                  : AppColors.textSecondary(dark),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : AppColors.textPrimary(dark),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (message.isEdited)
                      Text('edited  ',
                          style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white.withOpacity(0.6)
                                  : AppColors.textSecondary(dark),
                              fontStyle: FontStyle.italic)),
                    Text(
                      time,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textSecondary(dark),
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _MessageStatusIcon(
                        status: message.status,
                        showSeen: showSeen,
                        otherUser: otherUser,
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),

          // Reactions row below bubble
          if (hasReactions)
            Padding(
              padding: EdgeInsets.only(
                  bottom: 4,
                  left: isMe ? 0 : 14,
                  right: isMe ? 14 : 0),
              child: Wrap(
                spacing: 4,
                children: message.reactions.entries.map((e) {
                  final count = e.value.length;
                  final iMeReacted = e.value.contains(currentUid);
                  return GestureDetector(
                    onTap: () => chatService.toggleReaction(
                        chatId: chatId,
                        messageId: message.id,
                        emoji: e.key,
                        uid: currentUid),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iMeReacted
                            ? AppColors.primary.withOpacity(0.15)
                            : AppColors.bubbleOther(dark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: iMeReacted
                              ? AppColors.primary
                              : AppColors.divider(dark),
                        ),
                      ),
                      child: Text(
                        count > 1 ? '${e.key} $count' : e.key,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // (Seen avatar shown inside bubble via _MessageStatusIcon)
        ],
      ),
    );
  }
}

// ── Message status icon ────────────────────────────────────────────────────────
// Priority: showSeen > message.status
// showSeen = otherUser has seen this specific message (real-time from seenBy)
// message.status = 'sending'|'sent'|'delivered'|'seen'|'error'
class _MessageStatusIcon extends StatelessWidget {
  final String status;
  final bool showSeen;
  final UserModel? otherUser;

  const _MessageStatusIcon({
    required this.status,
    required this.showSeen,
    this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    // Seen: show tiny profile pic of the other person
    if (showSeen) {
      return ClipOval(
        child: SizedBox(
          width: 13,
          height: 13,
          child: AvatarWidget(user: otherUser, radius: 7),
        ),
      );
    }

    switch (status) {
      case 'sending':
        // Clock/single faint tick — not yet on server
        return Icon(Icons.access_time_rounded,
            size: 11, color: Colors.white.withOpacity(0.5));
      case 'delivered':
        // Double blue ticks — received on device
        return Icon(Icons.done_all,
            size: 13, color: Colors.lightBlueAccent.withOpacity(0.9));
      case 'seen':
        // Double blue ticks (fallback if showSeen not set yet)
        return Icon(Icons.done_all,
            size: 13, color: Colors.lightBlueAccent);
      case 'error':
        return const Icon(Icons.error_outline,
            size: 12, color: Colors.redAccent);
      case 'sent':
      default:
        // Single white tick — reached server
        return Icon(Icons.done,
            size: 13, color: Colors.white.withOpacity(0.75));
    }
  }
}

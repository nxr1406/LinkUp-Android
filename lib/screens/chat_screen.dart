import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/user_badges.dart';
import 'user_profile_view_screen.dart';
import 'group_settings_screen.dart';
import 'app_lock_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel? otherUser;
  final String currentUid;
  final String? groupName;
  final List<UserModel>? groupParticipants;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
    required this.currentUid,
    this.groupName,
    this.groupParticipants,
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

  // No scroll tracking needed — ListView uses reverse:true

  @override
  void initState() {
    super.initState();
    // First deliver, then mark as seen — correct order
    _markDeliveredThenRead();
    _msgCtrl.addListener(_onTextChanged);
  }

  /// Ensures correct flow: sent → delivered → seen
  Future<void> _markDeliveredThenRead() async {
    try {
      // Step 1: mark any 'sent' messages as 'delivered'
      await _chatService.markDelivered(
          chatId: widget.chatId, receiverUid: widget.currentUid);
      // Step 2: now mark everything (delivered + sent) as 'seen'
      await _chatService.markMessagesRead(
          chatId: widget.chatId, userId: widget.currentUid);
    } catch (_) {}
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

  ChatModel? _currentChat;


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

  void _scrollToBottom() {
    // With reverse:true, "bottom" is offset 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      final nearBottom = pos.pixels < 200; // reverse:true so 0 = bottom
      if (nearBottom) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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
    const dark = false;
    // Capture ChatScreen's context BEFORE showing bottom sheet
    final screenContext = context;
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
        // Pass ChatScreen context so dialog opens after sheet is fully closed
        onEdit: () {
          Navigator.pop(context);
          // Wait for bottom sheet to finish closing before showing dialog
          Future.delayed(const Duration(milliseconds: 150), () {
            if (screenContext.mounted) {
              _showEditDialogWithContext(screenContext, msg);
            }
          });
        },
      ),
    );
  }

  void _showEditDialogWithContext(BuildContext ctx, MessageModel msg) {
    final ctrl = TextEditingController(text: msg.text);
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
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
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              _chatService.editMessage(
                  chatId: widget.chatId,
                  messageId: msg.id,
                  newText: ctrl.text.trim());
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
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
    const dark = false;
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

  void _showChatInfoSheet(ChatModel? chat) {
    const dark = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(dark),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ChatInfoSheet(
        dark: dark,
        chat: chat,
        chatId: widget.chatId,
        currentUid: widget.currentUid,
        otherUser: widget.otherUser,
        chatService: _chatService,
        onNickname: () {
          Navigator.pop(context);
          _showNicknameDialog(chat);
        },
        onViewProfile: () {
          Navigator.pop(context);
          if (widget.otherUser != null) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        UserProfileViewScreen(user: widget.otherUser!)));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dark = false;

    return StreamBuilder<ChatModel?>(
      stream: _chatService.chatStream(widget.chatId),
      builder: (context, chatSnap) {
        final chat = chatSnap.data;
        // Keep _currentChat updated for settings checks
        if (chat != null && chat != _currentChat) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _currentChat = chat;
          });
        }
        final otherNick = chat?.nicknames[widget.otherUser?.uid ?? ''];
        // Respect OTHER person's typingIndicator setting
        final otherTypingEnabled =
            chat?.settings[widget.otherUser?.uid ?? '']?['typingIndicator'] ?? true;
        final isOtherTyping =
            otherTypingEnabled && chat?.typing[widget.otherUser?.uid ?? ''] == true;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary(dark), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: GestureDetector(
              onTap: () {
                if (widget.groupName == null && widget.otherUser != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UserProfileViewScreen(
                              user: widget.otherUser!)));
                }
              },
              child: Row(children: [
                // Group icon or user avatar
                widget.groupName != null
                    ? Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group_rounded,
                            color: AppColors.primary, size: 20),
                      )
                    : AvatarWidget(user: widget.otherUser, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              widget.groupName ??
                                  (otherNick?.isNotEmpty == true
                                      ? otherNick!
                                      : (widget.otherUser?.displayName ?? '...')),
                              style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          UserBadges(user: widget.otherUser, size: 14),
                        ]),
                        // Subtitle: group count / typing / last seen
                        if (widget.groupName != null)
                          Text(
                            '${(widget.groupParticipants?.length ?? 0) + 1} participants',
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 11),
                          )
                        else if (isOtherTyping)
                          Text('typing...',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic))
                        else
                          // Always show Online/Last seen below name (or nickname)
                          _LastSeenText(user: widget.otherUser, dark: dark),
                      ]),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded,
                    color: AppColors.textPrimary(dark)),
                onPressed: () => _showChatInfoSheet(chat),
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  // Only show loader on very first load (no data yet at all)
                  if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
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

                  // Scroll to bottom when new message arrives
                  // With reverse:true this just ensures we stay at offset 0

                  final reversed = messages.reversed.toList();

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: reversed.length,
                    itemBuilder: (context, index) {
                      final msg = reversed[index];
                      final isMe = msg.senderId == widget.currentUid;
                      final showDate = index == reversed.length - 1 ||
                          _formatDateHeader(msg.timestamp) !=
                              _formatDateHeader(
                                  reversed[index + 1].timestamp);

                      // showSeen: only the LAST message sent by me that is 'seen'
                      // Find the first (most recent since list is reversed) seen msg by me
                      final lastSeenIndex = reversed.indexWhere(
                          (m) => m.senderId == widget.currentUid && m.status == 'seen');
                      final showSeen = isMe &&
                          msg.status == 'seen' &&
                          index == lastSeenIndex;

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
                        // Seen label below last seen message
                        if (showSeen) const _SeenLabel(),
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
              const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
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
                hasText ? Icons.send_rounded : Icons.mic_none,
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
          icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(dark)),
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
  final VoidCallback onEdit;

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
    required this.onEdit,
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
          leading: const Icon(Icons.reply_rounded),
          title: const Text('Reply'),
          onTap: onReply,
        ),
        ListTile(
          leading: const Icon(Icons.reply_rounded),
          title: const Text('Forward'),
          onTap: onForward,
        ),
        ListTile(
          leading: const Icon(Icons.content_copy_rounded),
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
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Edit'),
            onTap: onEdit,
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline_rounded,
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
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
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

  String _formatLastSeen(DateTime lastSeen) {
    // Use server time comparison to avoid device clock mismatch
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inSeconds < 30) return 'Online now';
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';

    // Compare calendar days (not 24h window) to avoid "yesterday" vs "today" bug
    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final dayDiff = today.difference(seenDay).inDays;

    final hh = lastSeen.hour.toString().padLeft(2, '0');
    final mm = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hh:$mm';

    if (dayDiff == 0) return 'Last seen today at $timeStr';
    if (dayDiff == 1) return 'Last seen yesterday at $timeStr';
    return 'Last seen ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>?;
        final isOnline = data?['isOnline'] == true;

        // Online now — show green dot + text
        if (isOnline) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4CD964),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text('Online now',
                style: TextStyle(
                    color: const Color(0xFF4CD964),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]);
        }

        // Offline — show last seen with correct calendar day
        final rawTs = data?['lastSeen'];
        if (rawTs == null) return const SizedBox.shrink();
        final lastSeen = (rawTs as dynamic).toDate() as DateTime;

        return Text(
          _formatLastSeen(lastSeen),
          style: TextStyle(color: AppColors.textSecondary(dark), fontSize: 11),
        );
      },
    );
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
                  Icon(Icons.reply_rounded,
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

          // Nickname label above incoming bubble
          if (!isMe && otherNick?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 2, top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  otherNick!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (otherUser?.displayName?.isNotEmpty == true) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      otherUser!.displayName,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 10),
                    ),
                  ),
                ],
              ]),
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
// sent = single tick | delivered = double tick | seen = cyan double tick | error = red i
class _MessageStatusIcon extends StatelessWidget {
  final String status;
  final bool showSeen;
  final UserModel? otherUser;

  const _MessageStatusIcon({
    required this.status,
    required this.showSeen,
    this.otherUser,
  });

  static const Color _cyan = Color(0xFF00FFFF);

  @override
  Widget build(BuildContext context) {
    if (showSeen) {
      // Seen: cyan double tick
      return const Icon(Icons.done_all, size: 13, color: _cyan);
    }
    switch (status) {
      case 'sending':
        return Icon(Icons.access_time_rounded,
            size: 11, color: Colors.white.withOpacity(0.45));
      case 'delivered':
        return Icon(Icons.done_all,
            size: 13, color: Colors.white.withOpacity(0.9));
      case 'seen':
        return const Icon(Icons.done_all, size: 13, color: _cyan);
      case 'error':
        // Red circle-i
        return const Icon(Icons.info, size: 13, color: Colors.redAccent);
      case 'sent':
      default:
        return Icon(Icons.done,
            size: 13, color: Colors.white.withOpacity(0.75));
    }
  }
}

// ── Seen label shown under last seen message ──────────────────────────────────
class _SeenLabel extends StatelessWidget {
  const _SeenLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          Icon(Icons.done_all, size: 11, color: Color(0xFF4FC3F7)),
          SizedBox(width: 3),
          Text(
            'Seen',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF4FC3F7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Info Bottom Sheet ─────────────────────────────────────────────────────
class _ChatInfoSheet extends StatefulWidget {
  final bool dark;
  final ChatModel? chat;
  final String chatId, currentUid;
  final UserModel? otherUser;
  final ChatService chatService;
  final VoidCallback onNickname;
  final VoidCallback onViewProfile;

  const _ChatInfoSheet({
    required this.dark,
    required this.chat,
    required this.chatId,
    required this.currentUid,
    required this.otherUser,
    required this.chatService,
    required this.onNickname,
    required this.onViewProfile,
  });

  @override
  State<_ChatInfoSheet> createState() => _ChatInfoSheetState();
}

class _ChatInfoSheetState extends State<_ChatInfoSheet> {
  late bool _readReceipts;
  late bool _typingIndicator;

  @override
  void initState() {
    super.initState();
    final s = widget.chat?.settings[widget.currentUid];
    _readReceipts = s?['readReceipts'] ?? true;
    _typingIndicator = s?['typingIndicator'] ?? true;
  }

  Future<void> _setSetting(String key, bool value) async {
    await widget.chatService.setChatSetting(
      chatId: widget.chatId,
      uid: widget.currentUid,
      key: key,
      value: value,
    );
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block user?'),
        content: Text(
            "Block @${widget.otherUser?.username ?? ''}? They won't be able to message you."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await widget.chatService.blockUserFromChat(
        myUid: widget.currentUid,
        otherUid: widget.otherUser?.uid ?? '',
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppColors.textPrimary(widget.dark);
    final ts = AppColors.textSecondary(widget.dark);
    final div = AppColors.divider(widget.dark);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: div, borderRadius: BorderRadius.circular(2)),
          ),

          // Other user avatar + name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              AvatarWidget(user: widget.otherUser, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    widget.otherUser?.displayName ?? '',
                    style: TextStyle(
                        color: tc,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  Text('@${widget.otherUser?.username ?? ''}',
                      style: TextStyle(color: ts, fontSize: 13)),
                ]),
              ),
              TextButton(
                onPressed: widget.onViewProfile,
                child: Text('View Profile',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 13)),
              ),
            ]),
          ),

          Divider(color: div, height: 1),
          const SizedBox(height: 4),

          // Nickname option
          ListTile(
            leading: Icon(Icons.edit_rounded, color: tc, size: 22),
            title: Text('Set Nickname', style: TextStyle(color: tc)),
            subtitle: Text('Change display name in this chat',
                style: TextStyle(color: ts, fontSize: 12)),
            onTap: widget.onNickname,
          ),

          Divider(color: div, height: 1),

          // Read Receipts toggle
          ListTile(
            leading: Icon(Icons.done_all, color: tc, size: 22),
            title: Text('Read Receipts', style: TextStyle(color: tc)),
            subtitle: Text("Show when you've read messages",
                style: TextStyle(color: ts, fontSize: 12)),
            trailing: LinkUpToggle(
              value: _readReceipts,
              onChanged: (v) {
                setState(() => _readReceipts = v);
                _setSetting('readReceipts', v);
              },
            ),
          ),

          // Typing Indicator toggle
          ListTile(
            leading: Icon(Icons.keyboard_outlined, color: tc, size: 22),
            title: Text('Typing Indicator', style: TextStyle(color: tc)),
            subtitle: Text("Show when you're typing",
                style: TextStyle(color: ts, fontSize: 12)),
            trailing: LinkUpToggle(
              value: _typingIndicator,
              onChanged: (v) {
                setState(() => _typingIndicator = v);
                _setSetting('typingIndicator', v);
              },
            ),
          ),

          Divider(color: div, height: 1),

          // Block
          ListTile(
            leading:
                const Icon(Icons.block_rounded, color: Colors.redAccent, size: 22),
            title: const Text('Block',
                style: TextStyle(color: Colors.redAccent)),
            subtitle: Text('Block this person from messaging you',
                style: TextStyle(color: ts, fontSize: 12)),
            onTap: _blockUser,
          ),

          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}


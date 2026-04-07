import 'package:flutter/material.dart';
import '../models/message_model.dart';
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

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  Future<void> _markRead() async {
    try {
      await _chatService.markMessagesRead(
          chatId: widget.chatId, userId: widget.currentUid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending || widget.otherUser == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await _chatService.sendMessage(
        senderId: widget.currentUid,
        receiverId: widget.otherUser!.uid,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                      builder: (_) =>
                          UserProfileViewScreen(user: widget.otherUser!)));
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
                        widget.otherUser?.username ?? '...',
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
                    _LastSeenText(user: widget.otherUser, dark: dark),
                  ]),
            ),
          ]),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppColors.textPrimary(dark)),
            onPressed: () {
              if (widget.otherUser != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            UserProfileViewScreen(user: widget.otherUser!)));
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
                    child:
                        CircularProgressIndicator(color: AppColors.primary));
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text('Say hi! 👋',
                      style: TextStyle(
                          color: AppColors.textSecondary(dark), fontSize: 16)),
                );
              }
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == widget.currentUid;
                  final showDate = index == 0 ||
                      _formatDateHeader(msg.timestamp) !=
                          _formatDateHeader(messages[index - 1].timestamp);
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
                    _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      time: _formatTime(msg.timestamp),
                      dark: dark,
                      onLongPress: isMe ? () => _showDelete(msg) : null,
                    ),
                  ]);
                },
              );
            },
          ),
        ),
        _buildInputBar(dark),
      ]),
    );
  }

  void _showDelete(MessageModel msg) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg(dark),
        title: Text('Delete message?',
            style: TextStyle(color: AppColors.textPrimary(dark))),
        content: Text('This will delete the message for everyone.',
            style: TextStyle(color: AppColors.textSecondary(dark))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chatService.deleteMessage(
                  chatId: widget.chatId, messageId: msg.id);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
        // Camera button (UI only)
        Container(
          width: 38, height: 38,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
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
                hintStyle:
                    TextStyle(color: AppColors.textSecondary(dark)),
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
        style:
            TextStyle(color: AppColors.textSecondary(dark), fontSize: 11));
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe, dark;
  final String time;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message, required this.isMe, required this.time,
    required this.dark, this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
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
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
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
                  Icon(Icons.done_all,
                      size: 12, color: Colors.white.withOpacity(0.7)),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

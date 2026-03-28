import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:linkup_chat_app/models/message_model.dart';
import 'package:linkup_chat_app/providers/auth_provider.dart';
import 'package:linkup_chat_app/services/chat_service.dart';
import 'package:linkup_chat_app/widgets/chat/message_bubble.dart';
import 'package:linkup_chat_app/widgets/chat/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? recipientName;

  const ChatScreen({Key? key, required this.chatId, this.recipientName}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  bool _showEmojiPicker = false;
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return;
    _messageController.clear();
    await _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: auth.currentUser!.uid,
      text: text,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName ?? 'Chat'),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                final docs = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final message = MessageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                    final isMe = message.senderId == currentUser?.uid;
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      onReact: (emoji) {},
                      onReply: () {},
                    );
                  },
                );
              },
            ),
          ),
          if (_isTyping) const TypingIndicator(),
          _buildMessageInput(),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  _messageController.text += emoji.emoji;
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Message...',
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _isTyping = val.isNotEmpty),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

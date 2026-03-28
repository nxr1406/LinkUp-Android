import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:linkup_chat_app/providers/auth_provider.dart';
import 'package:linkup_chat_app/providers/chat_provider.dart';
import 'package:linkup_chat_app/widgets/chat/message_bubble.dart';
import 'package:linkup_chat_app/widgets/chat/typing_indicator.dart';
import 'package:linkup_chat_app/services/chat_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? recipientName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    this.recipientName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  String? _replyingToMessageId;
  String? _replyingToText;

  @override
  void initState() {
    super.initState();
    Provider.of<ChatProvider>(context, listen: false).setCurrentChat(widget.chatId);
    _setupTypingListener();
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      final isCurrentlyTyping = _messageController.text.isNotEmpty;
      if (isCurrentlyTyping != _isTyping) {
        _isTyping = isCurrentlyTyping;
        final userId = Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
        
        if (_isTyping) {
          _chatService.startTyping(widget.chatId, userId);
        } else {
          _chatService.stopTyping(widget.chatId, userId);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser!.uid;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    await chatProvider.sendMessage(
      chatId: widget.chatId,
      senderId: userId,
      text: _messageController.text.trim(),
      replyToMessageId: _replyingToMessageId,
    );
    
    _messageController.clear();
    _replyingToMessageId = null;
    _replyingToText = null;
    
    // Stop typing
    _chatService.stopTyping(widget.chatId, userId);
    
    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showEmojiPickerModal() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _onEmojiSelected(String emoji) {
    _messageController.text += emoji;
  }

  void _replyToMessage(String messageId, String messageText) {
    setState(() {
      _replyingToMessageId = messageId;
      _replyingToText = messageText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.recipientName ?? 'Chat',
              style: const TextStyle(fontSize: 16),
            ),
            StreamBuilder<List<String>>(
              stream: _chatService.getTypingUsers(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return const TypingIndicator();
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatProvider.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data!.docs;
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi!'),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final message = MessageModel.fromMap(messageData, messages[index].id);
                    final isMe = message.senderId == authProvider.currentUser?.uid;
                    
                    // Mark message as read
                    if (!isMe && !message.readBy.contains(authProvider.currentUser?.uid)) {
                      chatProvider.markMessageAsRead(
                        chatId: widget.chatId,
                        messageId: message.messageId,
                        userId: authProvider.currentUser!.uid,
                      );
                    }
                    
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      onReply: () => _replyToMessage(message.messageId, message.text),
                      onReact: (emoji) => chatProvider.addReaction(
                        chatId: widget.chatId,
                        messageId: message.messageId,
                        userId: authProvider.currentUser!.uid,
                        emoji: emoji,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyingToMessageId != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(
                          _replyingToText ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _replyingToMessageId = null;
                        _replyingToText = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: _showEmojiPickerModal,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _onEmojiSelected(emoji.emoji);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search'),
                onTap: () {
                  Navigator.pop(context);
                  _showSearchDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text('Pinned Messages'),
                onTap: () {
                  Navigator.pop(context);
                  _showPinnedMessages(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearChat(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlockUser(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Chat Info'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/chat-info', arguments: widget.chatId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return AlertDialog(
          title: const Text('Search Messages'),
          content: TextField(
            onChanged: (value) => searchQuery = value,
            decoration: const InputDecoration(
              hintText: 'Enter search term...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final results = await _chatService.searchMessages(
                  chatId: widget.chatId,
                  query: searchQuery,
                );
                Navigator.pop(context);
                _showSearchResults(context, results);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _showSearchResults(BuildContext context, List<MessageModel> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Search Results',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final message = results[index];
                      return ListTile(
                        title: Text(message.text),
                        subtitle: Text(
                          'From: ${message.senderId}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          // Scroll to message in chat
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPinnedMessages(BuildContext context) {
    // Implement pinned messages view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pinned messages feature coming soon')),
    );
  }

  void _confirmClearChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Chat'),
          content: const Text('Are you sure you want to clear all messages?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement clear chat
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared')),
                );
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  void _confirmBlockUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Block User'),
          content: const Text('Are you sure you want to block this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement block user
                Navigator.pop(context);
                Navigator.pop(context); // Close chat screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked')),
                );
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
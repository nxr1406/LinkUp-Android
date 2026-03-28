import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linkup_chat_app/models/chat_model.dart';
import 'package:linkup_chat_app/models/message_model.dart';
import 'package:linkup_chat_app/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _currentChatId;

  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentChatId => _currentChatId;

  void setCurrentChat(String chatId) {
    _currentChatId = chatId;
    notifyListeners();
  }

  Stream<QuerySnapshot> getChatsStream(String userId) {
    return _chatService.getChats(userId);
  }

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _chatService.getMessages(chatId);
  }

  Future<String> createOneToOneChat(String userId1, String userId2) async {
    _setLoading(true);
    try {
      String chatId = await _chatService.createOneToOneChat(userId1, userId2);
      return chatId;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> createGroupChat({
    required String groupName,
    required String createdBy,
    required List<String> participants,
    String? groupIcon,
  }) async {
    _setLoading(true);
    try {
      String chatId = await _chatService.createGroupChat(
        groupName: groupName,
        createdBy: createdBy,
        participants: participants,
        groupIcon: groupIcon,
      );
      return chatId;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? replyToMessageId,
    bool isForwarded = false,
  }) async {
    await _chatService.sendMessage(
      chatId: chatId,
      senderId: senderId,
      text: text,
      replyToMessageId: replyToMessageId,
      isForwarded: isForwarded,
    );
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    await _chatService.editMessage(
      chatId: chatId,
      messageId: messageId,
      newText: newText,
    );
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required bool forEveryone,
  }) async {
    await _chatService.deleteMessage(
      chatId: chatId,
      messageId: messageId,
      forEveryone: forEveryone,
    );
  }

  Future<void> addReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _chatService.addReaction(
      chatId: chatId,
      messageId: messageId,
      userId: userId,
      emoji: emoji,
    );
  }

  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    await _chatService.markMessageAsRead(
      chatId: chatId,
      messageId: messageId,
      userId: userId,
    );
  }

  void startTyping(String chatId, String userId) {
    _chatService.startTyping(chatId, userId);
  }

  void stopTyping(String chatId, String userId) {
    _chatService.stopTyping(chatId, userId);
  }

  Stream<List<String>> getTypingUsers(String chatId) {
    return _chatService.getTypingUsers(chatId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
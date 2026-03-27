import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSenderId;
  final Timestamp? lastMessageTime;
  final Map<String, int> unreadCount;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageTime,
    this.unreadCount = const {},
  });

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageTime: data['lastMessageTime'],
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
    );
  }
}

class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final Timestamp? createdAt;
  final Timestamp? expiresAt;
  final List<String> readBy;
  final bool isPending;
  final String? replyToId;
  final String? replyToText;
  final String? editedText;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    this.createdAt,
    this.expiresAt,
    this.readBy = const [],
    this.isPending = false,
    this.replyToId,
    this.replyToText,
    this.editedText,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      createdAt: data['createdAt'],
      expiresAt: data['expiresAt'],
      readBy: List<String>.from(data['readBy'] ?? []),
      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      editedText: data['editedText'],
    );
  }

  String get displayText => editedText ?? text;
}

class NotificationModel {
  final String id;
  final String userId;
  final String fromUserId;
  final String type;
  final String message;
  final Timestamp? createdAt;
  final bool read;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.type,
    this.message = '',
    this.createdAt,
    this.read = false,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      type: data['type'] ?? '',
      message: data['message'] ?? '',
      createdAt: data['createdAt'],
      read: data['read'] ?? false,
    );
  }
}

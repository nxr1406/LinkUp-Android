enum MessageType { text, image, video, audio, file, gif }

enum MessageStatus { sending, sent, delivered, seen }

class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String? text;
  final MessageType type;
  final DateTime timestamp;
  final List<String> readBy;
  final String? replyToMessageId;
  final bool isForwarded;
  final MessageStatus status;
  final String? mediaUrl;
  final Map<String, String>? reactions;
  final bool isDeleted;
  final bool isPinned;
  final bool isEdited;

  MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    this.text,
    required this.type,
    required this.timestamp,
    required this.readBy,
    this.replyToMessageId,
    this.isForwarded = false,
    this.status = MessageStatus.sent,
    this.mediaUrl,
    this.reactions,
    this.isDeleted = false,
    this.isPinned = false,
    this.isEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'readBy': readBy,
      'replyToMessageId': replyToMessageId,
      'isForwarded': isForwarded,
      'status': status.name,
      'mediaUrl': mediaUrl,
      'reactions': reactions,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isEdited': isEdited,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      messageId: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'],
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      readBy: List<String>.from(map['readBy'] ?? []),
      replyToMessageId: map['replyToMessageId'],
      isForwarded: map['isForwarded'] ?? false,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      mediaUrl: map['mediaUrl'],
      reactions: map['reactions'] != null
          ? Map<String, String>.from(map['reactions'])
          : null,
      isDeleted: map['isDeleted'] ?? false,
      isPinned: map['isPinned'] ?? false,
      isEdited: map['isEdited'] ?? false,
    );
  }

  MessageModel copyWith({
    String? text,
    MessageStatus? status,
    List<String>? readBy,
    Map<String, String>? reactions,
    bool? isDeleted,
    bool? isPinned,
    bool? isEdited,
  }) {
    return MessageModel(
      messageId: messageId,
      chatId: chatId,
      senderId: senderId,
      text: text ?? this.text,
      type: type,
      timestamp: timestamp,
      readBy: readBy ?? this.readBy,
      replyToMessageId: replyToMessageId,
      isForwarded: isForwarded,
      status: status ?? this.status,
      mediaUrl: mediaUrl,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

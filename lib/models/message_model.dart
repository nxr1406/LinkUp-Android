import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isUnsent;
  final bool isEdited;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final String? forwardedFrom;
  final Map<String, List<String>> reactions;
  // status: 'sending' | 'sent' | 'delivered' | 'seen' | 'error'
  final String status;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.isUnsent = false,
    this.isEdited = false,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.forwardedFrom,
    this.reactions = const {},
    this.status = 'sent',
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, List<String>> rxn = {};
    final raw = map['reactions'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) rxn[k.toString()] = List<String>.from(v);
      });
    }
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      isUnsent: map['isUnsent'] ?? false,
      isEdited: map['isEdited'] ?? false,
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      replyToSender: map['replyToSender'],
      forwardedFrom: map['forwardedFrom'],
      reactions: rxn,
      status: map['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
      'isUnsent': isUnsent,
      'isEdited': isEdited,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
      'reactions': reactions.map((k, v) => MapEntry(k, v)),
      'status': status,
    };
  }
}

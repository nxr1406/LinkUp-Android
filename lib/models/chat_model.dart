enum ChatType { oneToOne, group }

class ChatModel {
  final String chatId;
  final ChatType type;
  final List<String> participants;
  final String? groupName;
  final String? groupIcon;
  final String? createdBy;
  final List<String> admins;
  final DateTime updatedAt;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTime;

  ChatModel({
    required this.chatId,
    required this.type,
    required this.participants,
    this.groupName,
    this.groupIcon,
    this.createdBy,
    required this.admins,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'type': type.name,
      'participants': participants,
      'groupName': groupName,
      'groupIcon': groupIcon,
      'createdBy': createdBy,
      'admins': admins,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      chatId: id,
      type: ChatType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ChatType.oneToOne,
      ),
      participants: List<String>.from(map['participants'] ?? []),
      groupName: map['groupName'],
      groupIcon: map['groupIcon'],
      createdBy: map['createdBy'],
      admins: List<String>.from(map['admins'] ?? []),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
      lastMessage: map['lastMessage'],
      lastMessageSenderId: map['lastMessageSenderId'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
          : null,
    );
  }
}

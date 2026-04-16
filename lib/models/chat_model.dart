class ChatModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final String? lastMessageStatus; // sent / delivered / seen
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final Map<String, String> nicknames;
  final Map<String, DateTime?> seenBy;
  final Map<String, bool> typing;
  final Map<String, Map<String, bool>> settings;
  final Map<String, DateTime?> deletedFor; // uid → timestamp when deleted

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    this.lastMessageTime,
    this.unreadCount = const {},
    this.nicknames = const {},
    this.seenBy = const {},
    this.typing = const {},
    this.settings = const {},
    this.deletedFor = const {},
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, DateTime?> seenByParsed = {};
    final rawSeen = map['seenBy'];
    if (rawSeen is Map) {
      rawSeen.forEach((k, v) {
        seenByParsed[k.toString()] = v != null ? (v as dynamic).toDate() : null;
      });
    }
    Map<String, bool> typingParsed = {};
    final rawTyping = map['typing'];
    if (rawTyping is Map) {
      rawTyping.forEach((k, v) {
        typingParsed[k.toString()] = v == true;
      });
    }
    // Parse per-user settings
    Map<String, Map<String, bool>> settingsParsed = {};
    final rawSettings = map['settings'];
    if (rawSettings is Map) {
      rawSettings.forEach((k, v) {
        if (v is Map) {
          settingsParsed[k.toString()] = {
            'readReceipts': v['readReceipts'] != false, // default true
            'typingIndicator': v['typingIndicator'] != false,
          };
        }
      });
    }

    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageSenderId: map['lastMessageSenderId'],
      lastMessageStatus: map['lastMessageStatus'],
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as dynamic).toDate()
          : null,
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      nicknames: Map<String, String>.from(map['nicknames'] ?? {}),
      seenBy: seenByParsed,
      typing: typingParsed,
      settings: settingsParsed,
      deletedFor: () {
        final raw = map['deletedFor'];
        if (raw is! Map) return <String, DateTime?>{};
        final result = <String, DateTime?>{};
        (raw as Map<dynamic, dynamic>).forEach((k, v) {
          result[k.toString()] = v != null ? (v as dynamic).toDate() as DateTime : null;
        });
        return result;
      }(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
      'nicknames': nicknames,
    };
  }
}

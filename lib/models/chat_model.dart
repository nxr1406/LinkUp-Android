class ChatModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  // nicknames: { uid: nickname }
  final Map<String, String> nicknames;
  // seenBy: { uid: DateTime } — last time each participant read
  final Map<String, DateTime?> seenBy;
  // typing: { uid: bool }
  final Map<String, bool> typing;
  // settings: { uid: { 'readReceipts': bool, 'typingIndicator': bool } }
  final Map<String, Map<String, bool>> settings;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTime,
    this.unreadCount = const {},
    this.nicknames = const {},
    this.seenBy = const {},
    this.typing = const {},
    this.settings = const {},
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
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as dynamic).toDate()
          : null,
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      nicknames: Map<String, String>.from(map['nicknames'] ?? {}),
      seenBy: seenByParsed,
      typing: typingParsed,
      settings: settingsParsed,
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

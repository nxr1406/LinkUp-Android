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
  final Map<String, DateTime?> pinnedBy;   // uid → timestamp when pinned

  // ── Group fields ───────────────────────────────────────────────
  final bool isGroup;
  final String? groupName;
  final String? groupPhotoUrl;
  final String? createdBy;           // owner uid
  final List<String> groupAdmins;    // admin/moderator uids
  final Map<String, String> memberRoles; // uid → 'owner'|'admin'|'moderator'|'member'
  final Map<String, bool> mutedMembers;  // uid → isMuted

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
    this.pinnedBy = const {},
    this.isGroup = false,
    this.groupName,
    this.groupPhotoUrl,
    this.createdBy,
    this.groupAdmins = const [],
    this.memberRoles = const {},
    this.mutedMembers = const {},
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
          result[k.toString()] = v != null ? (v as dynamic).toDate() : null;
        });
        return result;
      }(),
      pinnedBy: () {
        final raw = map['pinnedBy'];
        if (raw is! Map) return <String, DateTime?>{};
        final result = <String, DateTime?>{};
        (raw as Map<dynamic, dynamic>).forEach((k, v) {
          result[k.toString()] = v != null ? (v as dynamic).toDate() : null;
        });
        return result;
      }(),
      // isGroup: true if explicitly set, OR if groupName exists (legacy groups)
      isGroup: map['isGroup'] == true || (map['groupName'] != null && (map['groupName'] as String).isNotEmpty),
      groupName: map['groupName'],
      groupPhotoUrl: map['groupPhotoUrl'],
      createdBy: map['createdBy'],
      groupAdmins: List<String>.from(map['groupAdmins'] ?? []),
      memberRoles: Map<String, String>.from(map['memberRoles'] ?? {}),
      mutedMembers: Map<String, bool>.from(map['mutedMembers'] ?? {}),
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

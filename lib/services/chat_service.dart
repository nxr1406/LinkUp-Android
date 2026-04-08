import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<ChatModel>> getUserChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<ChatModel?> chatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<String> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    String? forwardedFrom,
  }) async {
    final chatId = _chatId(senderId, receiverId);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final msgData = {
      'senderId': senderId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isUnsent': false,
      'isEdited': false,
      'reactions': {},
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
    };

    final batch = _firestore.batch();
    batch.set(msgRef, msgData);
    batch.set(
      chatRef,
      {
        'participants': [senderId, receiverId],
        'lastMessage': forwardedFrom != null ? '📨 Forwarded' : text.trim(),
        'lastMessageSenderId': senderId,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {receiverId: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return chatId;
  }

  Future<void> markMessagesRead({
    required String chatId,
    required String userId,
  }) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'unreadCount.$userId': 0,
      'seenBy.$userId': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true});
  }

  Future<void> unsentMessage({
    required String chatId,
    required String messageId,
  }) async {
    // Unsent = visible placeholder "Message was unsent"
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isUnsent': true, 'text': ''});
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Toggle reaction: if uid already reacted with emoji → remove, else add.
  /// One user can only have ONE emoji reaction per message.
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String uid,
  }) async {
    final ref = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final rawReactions = snap.data()?['reactions'] ?? {};
      final Map<String, List<String>> reactions = {};
      (rawReactions as Map).forEach((k, v) {
        if (v is List) reactions[k.toString()] = List<String>.from(v);
      });

      // Remove user from ALL emoji lists first (one reaction rule)
      reactions.forEach((e, uids) => uids.remove(uid));

      // If same emoji → remove (toggle off). Else add to new emoji.
      final existing = reactions[emoji] ?? [];
      // After removing uid above, if user WAS in this emoji it's now gone → add
      // But we need to check BEFORE removal. Use a flag approach:
      final wasInThisEmoji =
          (snap.data()?['reactions']?[emoji] as List?)?.contains(uid) ?? false;

      if (!wasInThisEmoji) {
        reactions[emoji] = [...existing, uid];
      }

      // Clean up empty lists
      reactions.removeWhere((_, v) => v.isEmpty);

      tx.update(ref, {'reactions': reactions});
    });
  }

  Future<void> setTyping({
    required String chatId,
    required String uid,
    required bool isTyping,
  }) async {
    await _firestore.collection('chats').doc(chatId).set(
      {'typing': {uid: isTyping}},
      SetOptions(merge: true),
    );
  }

  Future<void> setNickname({
    required String chatId,
    required String targetUid,
    required String nickname,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'nicknames.$targetUid': nickname,
    });
  }

  String getChatId(String uid1, String uid2) => _chatId(uid1, uid2);
}

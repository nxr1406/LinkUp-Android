import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // 'sent' = reached Firestore server successfully
      'status': 'sent',
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

  /// When receiver opens chat → mark sender's messages as 'delivered'
  Future<void> markDelivered({
    required String chatId,
    required String receiverUid,
  }) async {
    // Only filter by status — no compound index needed
    final msgs = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('status', isEqualTo: 'sent')
        .get();

    // Filter in Dart: only messages sent by the OTHER person
    final toUpdate = msgs.docs
        .where((d) => d.data()['senderId'] != receiverUid)
        .toList();

    if (toUpdate.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in toUpdate) {
      batch.update(doc.reference, {'status': 'delivered'});
    }
    await batch.commit();
  }

  /// When receiver reads messages → mark as 'seen'
  Future<void> markMessagesRead({
    required String chatId,
    required String userId,
  }) async {
    // Update chat-level seen timestamp + clear unread
    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'unreadCount.$userId': 0,
      'seenBy.$userId': FieldValue.serverTimestamp(),
    });

    // Only mark 'delivered' → 'seen' (not 'sent' → 'seen')
    // 'sent' → 'delivered' is handled separately by markDelivered()
    final deliveredSnap = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('status', isEqualTo: 'delivered')
        .get();

    // Filter in Dart to avoid composite index requirement
    final toUpdate = deliveredSnap.docs
        .where((d) => d.data()['senderId'] != userId)
        .toList();

    if (toUpdate.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in toUpdate) {
      batch.update(doc.reference, {'status': 'seen'});
    }
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
    final batch = _firestore.batch();

    // Mark message as unsent
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    batch.update(msgRef, {'isUnsent': true, 'text': ''});

    // Update chat lastMessage so home screen shows correct preview
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {'lastMessage': 'Message was unsent'});

    await batch.commit();
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

      // Check BEFORE any mutation whether user already reacted with this emoji
      final wasInThisEmoji =
          (snap.data()?['reactions']?[emoji] as List?)?.contains(uid) ?? false;

      // Remove user from ALL emoji lists (enforce one-reaction-per-user rule)
      reactions.forEach((_, uids) => uids.remove(uid));

      if (!wasInThisEmoji) {
        // Add to the chosen emoji
        reactions[emoji] = [...(reactions[emoji] ?? []), uid];
      }
      // else: wasInThisEmoji==true means we just toggled it off — already removed above

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
    await _firestore.collection('chats').doc(chatId).set(
      {'nicknames': {targetUid: nickname}},
      SetOptions(merge: true),
    );
  }

  Future<void> setChatSetting({
    required String chatId,
    required String uid,
    required String key,   // 'readReceipts' | 'typingIndicator'
    required bool value,
  }) async {
    await _firestore.collection('chats').doc(chatId).set(
      {'settings': {uid: {key: value}}},
      SetOptions(merge: true),
    );
  }

  Future<void> blockUserFromChat({
    required String myUid,
    required String otherUid,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .update({'blockedUsers': FieldValue.arrayUnion([otherUid])});
  }

  String getChatId(String uid1, String uid2) => _chatId(uid1, uid2);
}

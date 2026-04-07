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

  Future<String> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final chatId = _chatId(senderId, receiverId);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final message = MessageModel(
      id: msgRef.id,
      senderId: senderId,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    final batch = _firestore.batch();

    batch.set(msgRef, {
      ...message.toMap(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.set(
      chatRef,
      {
        'participants': [senderId, receiverId],
        'lastMessage': text.trim(),
        'lastMessageSenderId': senderId,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          receiverId: FieldValue.increment(1),
        },
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
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$userId': 0,
    });
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

  String getChatId(String uid1, String uid2) => _chatId(uid1, uid2);
}

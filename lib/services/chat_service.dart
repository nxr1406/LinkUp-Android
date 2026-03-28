import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linkup_chat_app/models/chat_model.dart';
import 'package:linkup_chat_app/models/message_model.dart';
import 'package:linkup_chat_app/models/user_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createOneToOneChat(String userId1, String userId2) async {
    try {
      String chatId = _generateChatId(userId1, userId2);
      
      // Check if chat already exists
      DocumentSnapshot existingChat = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();
      
      if (existingChat.exists) {
        return chatId;
      }
      
      ChatModel chat = ChatModel(
        chatId: chatId,
        type: ChatType.oneToOne,
        participants: [userId1, userId2],
        admins: [],
        updatedAt: DateTime.now(),
      );
      
      await _firestore.collection('chats').doc(chatId).set(chat.toMap());
      return chatId;
    } catch (e) {
      print('Error creating one-to-one chat: $e');
      rethrow;
    }
  }
  
  String _generateChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String> createGroupChat({
    required String groupName,
    required String createdBy,
    required List<String> participants,
    String? groupIcon,
  }) async {
    try {
      String chatId = _firestore.collection('chats').doc().id;
      
      ChatModel chat = ChatModel(
        chatId: chatId,
        type: ChatType.group,
        participants: [createdBy, ...participants],
        groupName: groupName,
        groupIcon: groupIcon,
        createdBy: createdBy,
        admins: [createdBy],
        updatedAt: DateTime.now(),
      );
      
      await _firestore.collection('chats').doc(chatId).set(chat.toMap());
      return chatId;
    } catch (e) {
      print('Error creating group chat: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? replyToMessageId,
    bool isForwarded = false,
  }) async {
    try {
      String messageId = _firestore.collection('chats').doc(chatId)
          .collection('messages').doc().id;
      
      MessageModel message = MessageModel(
        messageId: messageId,
        chatId: chatId,
        senderId: senderId,
        text: text,
        type: MessageType.text,
        timestamp: DateTime.now(),
        readBy: [senderId],
        replyToMessageId: replyToMessageId,
        isForwarded: isForwarded,
        status: MessageStatus.sent,
      );
      
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
      
      // Update last message in chat
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
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
        .update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required bool forEveryone,
  }) async {
    if (forEveryone) {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'text': 'This message was deleted',
      });
    } else {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    }
  }

  Future<void> addReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    DocumentReference messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(messageRef);
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      
      Map<String, dynamic> reactions = data?['reactions'] ?? {};
      List<String> users = List<String>.from(reactions[emoji] ?? []);
      
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      
      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }
      
      transaction.update(messageRef, {'reactions': reactions});
    });
  }

  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    DocumentReference messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(messageRef);
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      
      List<String> readBy = List<String>.from(data?['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        readBy.add(userId);
        transaction.update(messageRef, {'readBy': readBy});
      }
    });
  }

  Future<void> startTyping(String chatId, String userId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId)
        .set({
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopTyping(String chatId, String userId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId)
        .delete();
  }

  Stream<List<String>> getTypingUsers(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            DateTime timestamp = (doc['timestamp'] as Timestamp).toDate();
            return DateTime.now().difference(timestamp) < Duration(seconds: 3);
          })
          .map((doc) => doc['userId'] as String)
          .toList();
    });
  }

  Future<void> pinMessage({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(chatRef);
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      
      Map<String, dynamic> pinnedMessages = data?['pinnedMessages'] ?? {};
      pinnedMessages[messageId] = userId;
      
      transaction.update(chatRef, {'pinnedMessages': pinnedMessages});
    });
  }

  Future<void> unpinMessage({
    required String chatId,
    required String messageId,
  }) async {
    DocumentReference chatRef = _firestore.collection('chats').doc(chatId);
    
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(chatRef);
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      
      Map<String, dynamic> pinnedMessages = data?['pinnedMessages'] ?? {};
      pinnedMessages.remove(messageId);
      
      transaction.update(chatRef, {'pinnedMessages': pinnedMessages});
    });
  }

  Future<List<MessageModel>> searchMessages({
    required String chatId,
    required String query,
  }) async {
    QuerySnapshot snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('text', isGreaterThanOrEqualTo: query)
        .where('text', isLessThan: query + '\uf8ff')
        .limit(50)
        .get();
    
    return snapshot.docs.map((doc) {
      return MessageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }
}
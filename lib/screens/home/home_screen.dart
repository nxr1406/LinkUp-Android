import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linkup_chat_app/models/chat_model.dart';
import 'package:linkup_chat_app/providers/auth_provider.dart';
import 'package:linkup_chat_app/screens/chat/chat_screen.dart';
import 'package:linkup_chat_app/screens/profile/profile_screen.dart';
import 'package:linkup_chat_app/services/chat_service.dart';
import 'package:linkup_chat_app/widgets/chat/chat_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkUp', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _chatService.getChats(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No chats yet.\nStart a conversation!', textAlign: TextAlign.center));
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final chat = ChatModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                    final otherUserId = chat.participants.firstWhere(
                      (id) => id != currentUser.uid,
                      orElse: () => '',
                    );
                    return FutureBuilder<DocumentSnapshot>(
                      future: otherUserId.isNotEmpty
                          ? FirebaseFirestore.instance.collection('users').doc(otherUserId).get()
                          : Future.value(null as dynamic),
                      builder: (context, userSnap) {
                        String? name, photo;
                        if (userSnap.hasData && userSnap.data != null) {
                          final data = userSnap.data!.data() as Map<String, dynamic>?;
                          name = data?['username'];
                          photo = data?['photoURL'];
                        }
                        return ChatTile(
                          chat: chat,
                          currentUserId: currentUser.uid,
                          otherUserName: name,
                          otherUserPhoto: photo,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chat.chatId,
                                recipientName: chat.type == ChatType.group ? chat.groupName : name,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/avatar_widget.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(onPressed: () => context.go('/app/profile'), icon: const Icon(Icons.arrow_back_ios, size: 20)),
      ),
      body: uid == null ? const SizedBox() : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications')
            .where('toUserId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5865F2), strokeWidth: 2));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No notifications yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ]));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final ts = data['createdAt'] as Timestamp?;
              return ListTile(
                onTap: () { if (data['chatId'] != null) context.go('/chat/${data['chatId']}'); },
                leading: AvatarWidget(url: data['fromUserAvatar'], name: data['fromUserName'] ?? '', size: 44),
                title: RichText(text: TextSpan(style: const TextStyle(fontSize: 14, color: Color(0xFF262626)), children: [
                  TextSpan(text: data['fromUserName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' ${data['message'] ?? 'sent you a message'}'),
                ])),
                trailing: ts != null ? Text(timeago.format(ts.toDate()), style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))) : null,
              );
            },
          );
        },
      ),
    );
  }
}

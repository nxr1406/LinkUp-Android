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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: currentUser == null
          ? const SizedBox()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('toUserId', isEqualTo: currentUser.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0095F6), strokeWidth: 2));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Color(0xFFDBDBDB)),
                        SizedBox(height: 12),
                        Text('No notifications yet',
                            style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8E8E8E))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    final ts = data['createdAt'] as Timestamp?;
                    final timeStr =
                        ts != null ? timeago.format(ts.toDate()) : '';

                    return ListTile(
                      onTap: () {
                        if (data['chatId'] != null) {
                          context.go('/chat/${data['chatId']}');
                        }
                      },
                      leading: AvatarWidget(
                        url: data['fromUserAvatar'],
                        name: data['fromUserName'] ?? '',
                        size: 44,
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF262626)),
                          children: [
                            TextSpan(
                              text: data['fromUserName'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: ' ${data['message'] ?? 'sent you a message'}',
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(timeStr,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E8E))),
                    );
                  },
                );
              },
            ),
    );
  }
}

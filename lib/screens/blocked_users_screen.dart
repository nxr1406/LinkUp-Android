import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
      BuildContext context, String uid, String targetId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'blockedUsers': FieldValue.arrayRemove([targetId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('User unblocked'),
            backgroundColor: Colors.green),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to unblock'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<LinkUpAuthProvider>();
    final blockedIds =
        (auth.userData?['blockedUsers'] as List?)?.cast<String>() ?? [];
    final uid = auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: blockedIds.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Color(0xFFDBDBDB)),
                  SizedBox(height: 12),
                  Text('No blocked users',
                      style: TextStyle(
                          fontSize: 16, color: Color(0xFF8E8E8E))),
                ],
              ),
            )
          : ListView.builder(
              itemCount: blockedIds.length,
              itemBuilder: (context, i) {
                final targetId = blockedIds[i];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(targetId)
                      .get(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox(height: 60);
                    final data =
                        snap.data!.data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox();

                    return ListTile(
                      leading: AvatarWidget(
                        url: data['avatarUrl'],
                        name: data['fullName'] ?? '',
                        size: 44,
                      ),
                      title: Text(
                        data['username'] ?? '',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        data['fullName'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF8E8E8E)),
                      ),
                      trailing: TextButton(
                        onPressed: uid != null
                            ? () => _unblock(context, uid, targetId)
                            : null,
                        child: const Text(
                          'Unblock',
                          style: TextStyle(
                            color: Color(0xFF0095F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';

class AdminVerificationScreen extends StatelessWidget {
  const AdminVerificationScreen({super.key});

  Future<void> _approve(String requestId, String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(requestId),
      {'status': 'approved'},
    );
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(userId),
      {'isVerified': true, 'verificationStatus': 'approved'},
    );
    await batch.commit();
  }

  Future<void> _reject(String requestId, String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(requestId),
      {'status': 'rejected'},
    );
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(userId),
      {'verificationStatus': 'rejected'},
    );
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Requests',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('verificationRequests')
            .where('status', isEqualTo: 'pending')
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
              child: Text('No pending verification requests',
                  style: TextStyle(
                      fontSize: 15, color: Color(0xFF8E8E8E))),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final ts = data['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarWidget(
                            url: data['avatarUrl'],
                            name: data['fullName'] ?? '',
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['fullName'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              Text('@${data['username'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8E8E8E))),
                            ],
                          ),
                          const Spacer(),
                          if (ts != null)
                            Text(timeago.format(ts.toDate()),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8E8E8E))),
                        ],
                      ),
                      if (data['link'] != null) ...[
                        const SizedBox(height: 8),
                        Text('Link: ${data['link']}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0095F6))),
                      ],
                      if (data['category'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF8FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            data['category'],
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0095F6)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(
                                  docs[i].id, data['userId']),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFFED4956)),
                                foregroundColor:
                                    const Color(0xFFED4956),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approve(
                                  docs[i].id, data['userId']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF0095F6),
                              ),
                              child: const Text('Approve',
                                  style: TextStyle(
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
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

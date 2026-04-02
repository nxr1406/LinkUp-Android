import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/avatar_widget.dart';

class AdminAppealsScreen extends StatelessWidget {
  const AdminAppealsScreen({super.key});

  Future<void> _resolve(BuildContext context, String appealId, String userId, String status) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('appeals').doc(appealId), {'status': status});
      final userUpdate = status == 'approved'
          ? {'isSuspended': false, 'appealStatus': 'approved'}
          : {'appealStatus': 'rejected'};
      batch.update(FirebaseFirestore.instance.collection('users').doc(userId), userUpdate);
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appeals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('appeals').where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No pending appeals', style: TextStyle(fontSize: 15, color: Color(0xFF8E8E8E))));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final ts = data['createdAt'] as Timestamp?;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AvatarWidget(url: data['avatarUrl'], name: data['fullName'] ?? '', size: 44),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(data['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('@${data['username'] ?? ''}', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
                        ])),
                        if (ts != null) Text(timeago.format(ts.toDate()), style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                        child: Text(data['message'] ?? '', style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => _resolve(context, docs[i].id, data['userId'], 'rejected'),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFED4956)), foregroundColor: const Color(0xFFED4956)),
                          child: const Text('Reject'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(
                          onPressed: () => _resolve(context, docs[i].id, data['userId'], 'approved'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Approve', style: TextStyle(color: Colors.white)),
                        )),
                      ]),
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

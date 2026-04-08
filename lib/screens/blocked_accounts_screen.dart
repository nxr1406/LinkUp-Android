import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../models/user_model.dart';

class BlockedAccountsScreen extends StatelessWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(dark),
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg(dark),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.textPrimary(dark), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Blocked Accounts',
            style: TextStyle(
                color: AppColors.textPrimary(dark),
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final data = snap.data!.data() as Map<String, dynamic>?;
          final blockedIds =
              List<String>.from(data?['blockedUsers'] ?? []);

          if (blockedIds.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block,
                        size: 64,
                        color: AppColors.textSecondary(dark)
                            .withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text('No blocked accounts',
                        style: TextStyle(
                            color: AppColors.textSecondary(dark),
                            fontSize: 15)),
                  ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: blockedIds.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(blockedIds[index])
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox.shrink();
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox.shrink();
                  final user =
                      UserModel.fromMap(userData, userSnap.data!.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(dark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: AvatarWidget(user: user, radius: 22),
                      title: Text(user.username,
                          style: TextStyle(
                              color: AppColors.textPrimary(dark),
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(user.displayName,
                          style: TextStyle(
                              color: AppColors.textSecondary(dark),
                              fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({
                            'blockedUsers':
                                FieldValue.arrayRemove([blockedIds[index]])
                          });
                        },
                        child: const Text('Unblock',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

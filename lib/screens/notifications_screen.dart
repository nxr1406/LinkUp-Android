import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/user_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _notificationsEnabled = true;

  Future<void> _toggleNotifications(ap.AuthProvider auth) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final newState = !_notificationsEnabled;
    setState(() => _notificationsEnabled = newState);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'notificationsEnabled': newState,
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    _notificationsEnabled = auth.userData?.notificationsEnabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ap.AuthProvider>(context);
    final currentUser = auth.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        size: 20, color: AppColors.text),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Notifications',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Pause toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pause All',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                      SizedBox(height: 2),
                      Text('Temporarily pause notifications',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.subText)),
                    ],
                  ),
                  Switch(
                    value: !_notificationsEnabled,
                    onChanged: (_) => _toggleNotifications(auth),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            // Notifications list
            Expanded(
              child: currentUser == null
                  ? const SizedBox()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('userId', isEqualTo: currentUser.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    size: 64, color: AppColors.border),
                                SizedBox(height: 12),
                                Text('No notifications yet',
                                    style: TextStyle(
                                        color: AppColors.subText,
                                        fontSize: 14)),
                              ],
                            ),
                          );
                        }

                        docs.sort((a, b) {
                          final tA = (a.data()
                                  as Map)['createdAt'] as Timestamp?;
                          final tB = (b.data()
                                  as Map)['createdAt'] as Timestamp?;
                          return (tB?.millisecondsSinceEpoch ?? 0)
                              .compareTo(tA?.millisecondsSinceEpoch ?? 0);
                        });

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final data =
                                docs[i].data() as Map<String, dynamic>;
                            final fromUserId =
                                data['fromUserId'] as String? ?? '';
                            final createdAt =
                                data['createdAt'] as Timestamp?;
                            final message =
                                data['message'] as String? ?? '';
                            final isRead = data['read'] as bool? ?? false;

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(fromUserId)
                                  .get(),
                              builder: (_, userSnap) {
                                UserModel? fromUser;
                                if (userSnap.hasData &&
                                    userSnap.data!.exists) {
                                  fromUser =
                                      UserModel.fromDoc(userSnap.data!);
                                }

                                return Container(
                                  color: isRead
                                      ? null
                                      : AppColors.primary.withOpacity(0.05),
                                  child: ListTile(
                                    leading: UserAvatar(
                                      avatarUrl: fromUser?.avatarUrl,
                                      name: fromUser?.fullName,
                                      size: 44,
                                    ),
                                    title: Text(
                                        fromUser?.fullName ?? 'User',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text)),
                                    subtitle: Text(
                                        message,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.subText)),
                                    trailing: Text(
                                        formatTimeAgo(createdAt),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.subText)),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<UserModel> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final blockedIds = auth.userData?.blockedUsers ?? [];

    if (blockedIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final users = await Future.wait(blockedIds.map((id) async {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        return doc.exists ? UserModel.fromDoc(doc) : null;
      }));

      setState(() {
        _blockedUsers =
            users.whereType<UserModel>().toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String userId) async {
    final auth = Provider.of<ap.AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });

      setState(() {
        _blockedUsers.removeWhere((u) => u.id == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User unblocked'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Unblock error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Text('Blocked Accounts',
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
            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _blockedUsers.isEmpty
                      ? const Center(
                          child: Text(
                            "You haven't blocked anyone.",
                            style: TextStyle(
                                color: AppColors.subText, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _blockedUsers.length,
                          itemBuilder: (_, i) {
                            final user = _blockedUsers[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    avatarUrl: user.avatarUrl,
                                    name: user.fullName,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(user.fullName,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.text)),
                                        Text('@${user.username}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.subText)),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _unblock(user.id),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: AppColors.border),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Unblock',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
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

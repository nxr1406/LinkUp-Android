import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/verification_model.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/user_badges.dart';

class AdminScreen extends StatefulWidget {
  final int tab;
  const AdminScreen({super.key, this.tab = 0});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.tab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Admin Panel',
            style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Verifications'),
            Tab(text: 'Appeals'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VerificationsTab(userService: _userService),
          _AppealsTab(userService: _userService),
          _UsersTab(userService: _userService),
        ],
      ),
    );
  }
}

// ---- Verifications Tab ----
class _VerificationsTab extends StatelessWidget {
  final UserService userService;
  const _VerificationsTab({required this.userService});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<VerificationRequest>>(
      stream: userService.getVerificationRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(
              child: Text('No pending verification requests',
                  style: TextStyle(color: AppColors.grey)));
        }
        return ListView.builder(
          itemCount: requests.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final req = requests[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade200,
                          child: Text(req.displayName.isNotEmpty
                              ? req.displayName[0].toUpperCase()
                              : '?'),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('@${req.username}',
                                style: const TextStyle(
                                    color: AppColors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(req.reason,
                        style: const TextStyle(
                            color: AppColors.textMedium, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await userService.reviewVerification(
                                requestId: req.id,
                                userId: req.userId,
                                approve: false,
                                reviewerId: me,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await userService.reviewVerification(
                                requestId: req.id,
                                userId: req.userId,
                                approve: true,
                                reviewerId: me,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('Approve'),
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
    );
  }
}

// ---- Appeals Tab ----
class _AppealsTab extends StatelessWidget {
  final UserService userService;
  const _AppealsTab({required this.userService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SuspensionAppeal>>(
      stream: userService.getSuspensionAppeals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final appeals = snapshot.data ?? [];
        if (appeals.isEmpty) {
          return const Center(
              child: Text('No pending suspension appeals',
                  style: TextStyle(color: AppColors.grey)));
        }
        return ListView.builder(
          itemCount: appeals.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final appeal = appeals[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${appeal.username}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(appeal.reason,
                        style: const TextStyle(
                            color: AppColors.textMedium, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await userService.reviewSuspensionAppeal(
                                  appealId: appeal.id,
                                  userId: appeal.userId,
                                  approve: false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await userService.reviewSuspensionAppeal(
                                  appealId: appeal.id,
                                  userId: appeal.userId,
                                  approve: true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('Unsuspend'),
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
    );
  }
}

// ---- Users Tab (Admin manage all users) ----
class _UsersTab extends StatelessWidget {
  final UserService userService;
  const _UsersTab({required this.userService});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<UserModel>>(
      stream: userService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final users = snapshot.data ?? [];
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            if (user.uid == me) return const SizedBox.shrink();
            return ListTile(
              leading: AvatarWidget(user: user, radius: 22),
              title: Row(
                children: [
                  Text(user.username,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  UserBadges(user: user, size: 13),
                  if (user.isSuspended) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.block_rounded, color: Colors.red, size: 13),
                  ],
                ],
              ),
              subtitle: Text(user.email,
                  style:
                      const TextStyle(color: AppColors.grey, fontSize: 12)),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'suspend':
                      await userService.suspendUser(user.uid);
                      break;
                    case 'unsuspend':
                      await userService.unsuspendUser(user.uid);
                      break;
                    case 'make_admin':
                      await userService.setAdminStatus(user.uid, true);
                      break;
                    case 'remove_admin':
                      await userService.setAdminStatus(user.uid, false);
                      break;
                    case 'verify':
                      await userService.setVerified(user.uid, true);
                      break;
                    case 'unverify':
                      await userService.setVerified(user.uid, false);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (!user.isSuspended)
                    const PopupMenuItem(
                        value: 'suspend',
                        child: Text('Suspend',
                            style: TextStyle(color: Colors.red)))
                  else
                    const PopupMenuItem(
                        value: 'unsuspend',
                        child: Text('Unsuspend',
                            style: TextStyle(color: Colors.green))),
                  if (!user.isAdmin)
                    const PopupMenuItem(
                        value: 'make_admin',
                        child: Text('Make Admin'))
                  else
                    const PopupMenuItem(
                        value: 'remove_admin',
                        child: Text('Remove Admin')),
                  if (!user.isVerified)
                    const PopupMenuItem(
                        value: 'verify',
                        child: Text('Verify',
                            style: TextStyle(color: Colors.green)))
                  else
                    const PopupMenuItem(
                        value: 'unverify',
                        child: Text('Remove Verified',
                            style: TextStyle(color: Colors.orange))),
                ],
                icon: const Icon(Icons.more_vert, color: AppColors.grey),
              ),
            );
          },
        );
      },
    );
  }
}

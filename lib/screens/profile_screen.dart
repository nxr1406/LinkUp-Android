import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart' as ap;
import '../services/catbox_service.dart';
import '../utils/theme.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showMenu = false;
  bool _showEdit = false;

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _avatarFile;
  bool _saving = false;

  void _openEdit(ap.AuthProvider auth) {
    _nameCtrl.text = auth.userData?.fullName ?? '';
    _usernameCtrl.text = auth.userData?.username ?? '';
    _bioCtrl.text = auth.userData?.bio ?? '';
    setState(() => _showEdit = true);
  }

  Future<void> _saveProfile(ap.AuthProvider auth) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    setState(() => _saving = true);

    try {
      String avatarUrl = auth.userData?.avatarUrl ?? '';
      if (_avatarFile != null) {
        final url = await CatboxService.uploadImage(_avatarFile!);
        if (url != null) avatarUrl = url;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'fullName': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'bio': _bioCtrl.text.trim(),
        'avatarUrl': avatarUrl,
      });

      if (mounted) {
        setState(() => _showEdit = false);
        _showSnack('Profile updated', success: true);
      }
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _logout() async {
    await ap.AuthProvider().setOffline();
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _deleteAccount(ap.AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all messages. This can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final uid = auth.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await auth.currentUser!.delete();
      if (mounted) context.go('/login');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ap.AuthProvider>(context);
    final userData = auth.userData;

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: AppColors.text),
                        const SizedBox(width: 4),
                        Text(userData?.username ?? '',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                      ]),
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.add_box_outlined,
                              size: 24, color: AppColors.text),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu,
                              size: 24, color: AppColors.text),
                          onPressed: () => setState(() => _showMenu = true),
                        ),
                      ]),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Avatar
                        UserAvatar(
                          avatarUrl: userData?.avatarUrl,
                          name: userData?.fullName,
                          size: 112,
                        ),
                        const SizedBox(height: 16),
                        Text(userData?.fullName ?? '',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text)),
                        if (userData?.bio?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(userData!.bio,
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.subText),
                                textAlign: TextAlign.center),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Stats
                        _chatCountRow(auth),
                        const SizedBox(height: 20),
                        // Edit button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: OutlinedButton(
                            onPressed: () => _openEdit(auth),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 36),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Edit Profile',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Menu items
                        _menuTile(
                          Icons.notifications_outlined,
                          'Notifications',
                          () => context.go('/app/notifications'),
                        ),
                        _menuTile(
                          Icons.block,
                          'Blocked Accounts',
                          () => context.go('/app/blocked'),
                        ),
                        _menuTile(
                          Icons.privacy_tip_outlined,
                          'Privacy Policy',
                          () => context.go('/app/privacy'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Menu sheet
        if (_showMenu) _menuSheet(auth),
        // Edit sheet
        if (_showEdit) _editSheet(auth),
      ],
    );
  }

  Widget _chatCountRow(ap.AuthProvider auth) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: auth.currentUser?.uid)
          .get(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Column(
          children: [
            Text('$count',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
            const Text('Chats',
                style: TextStyle(fontSize: 13, color: AppColors.subText)),
          ],
        );
      },
    );
  }

  Widget _menuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.text, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 15, color: AppColors.text)),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.subText, size: 20),
      onTap: onTap,
    );
  }

  Widget _menuSheet(ap.AuthProvider auth) {
    return GestureDetector(
      onTap: () => setState(() => _showMenu = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.text),
                      title: const Text('Log out',
                          style: TextStyle(fontSize: 15, color: AppColors.text)),
                      onTap: () {
                        setState(() => _showMenu = false);
                        _logout();
                      },
                    ),
                    const Divider(height: 0, color: AppColors.border),
                    ListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      title: const Text('Delete Account',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.error)),
                      onTap: () {
                        setState(() => _showMenu = false);
                        _deleteAccount(auth);
                      },
                    ),
                    const Divider(height: 0, color: AppColors.border),
                    ListTile(
                      title: const Text('Cancel',
                          style: TextStyle(fontSize: 15, color: AppColors.text),
                          textAlign: TextAlign.center),
                      onTap: () => setState(() => _showMenu = false),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editSheet(ap.AuthProvider auth) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Edit header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: AppColors.border, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.text),
                      onPressed: () => setState(() => _showEdit = false),
                    ),
                    const Text('Edit Profile',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    IconButton(
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check, color: AppColors.primary),
                      onPressed: _saving ? null : () => _saveProfile(auth),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.border,
                              backgroundImage: _avatarFile != null
                                  ? FileImage(_avatarFile!)
                                  : null,
                              child: _avatarFile == null
                                  ? (auth.userData?.avatarUrl?.isNotEmpty ==
                                          true
                                      ? null
                                      : const Icon(Icons.person,
                                          color: Colors.white, size: 40))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameCtrl,
                        decoration:
                            const InputDecoration(hintText: 'Full Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameCtrl,
                        decoration:
                            const InputDecoration(hintText: 'Username'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'Bio'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }
}

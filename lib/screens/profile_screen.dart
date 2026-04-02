import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showMenu = false;
  bool _showEdit = false;

  final _editNameCtrl = TextEditingController();
  final _editUsernameCtrl = TextEditingController();
  final _editBioCtrl = TextEditingController();
  File? _newAvatar;
  bool _saving = false;

  Future<String?> _uploadToCatbox(File file) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('https://catbox.moe/user/api.php'));
      request.fields['reqtype'] = 'fileupload';
      request.files
          .add(await http.MultipartFile.fromPath('fileToUpload', file.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.bytesToString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveProfile() async {
    final auth =
        Provider.of<LinkUpAuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      String? avatarUrl;
      if (_newAvatar != null) {
        avatarUrl = await _uploadToCatbox(_newAvatar!);
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _editNameCtrl.text.trim(),
        'username': _editUsernameCtrl.text.trim().toLowerCase(),
        'bio': _editBioCtrl.text.trim(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      });

      setState(() => _showEdit = false);
      _showSnack('Profile updated', isSuccess: true);
    } catch (_) {
      _showSnack('Failed to update profile');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<LinkUpAuthProvider>();
    final userData = auth.userData;
    final currentUser = auth.currentUser;

    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              userData['username'] ?? '',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (userData['isVerified'] == true) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 16),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showMenu = !_showMenu),
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Avatar
                AvatarWidget(
                  url: userData['avatarUrl'],
                  name: userData['fullName'] ?? '',
                  size: 80,
                ),
                const SizedBox(height: 12),

                // Full name
                Text(
                  userData['fullName'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF262626),
                  ),
                ),

                // Bio
                if ((userData['bio'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      userData['bio'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF8E8E8E)),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Edit Profile Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton(
                    onPressed: () {
                      _editNameCtrl.text = userData['fullName'] ?? '';
                      _editUsernameCtrl.text = userData['username'] ?? '';
                      _editBioCtrl.text = userData['bio'] ?? '';
                      setState(() => _showEdit = true);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                      side: const BorderSide(color: Color(0xFFDBDBDB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(
                          color: Color(0xFF262626),
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFDBDBDB)),

                // Menu items
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () => context.go('/app/notifications'),
                ),
                _MenuItem(
                  icon: Icons.lock_outline,
                  title: 'Privacy',
                  onTap: () => context.go('/app/blocked'),
                ),
                if (userData['role'] == 'admin') ...[
                  const Divider(color: Color(0xFFDBDBDB)),
                  _MenuItem(
                    icon: Icons.verified_outlined,
                    title: 'Verification Requests',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.gavel_outlined,
                    title: 'Appeals',
                    onTap: () {},
                  ),
                ],
                const Divider(color: Color(0xFFDBDBDB)),
                _MenuItem(
                  icon: Icons.logout,
                  title: 'Log out',
                  color: const Color(0xFFED4956),
                  onTap: () async {
                    await auth.signOut();
                    if (mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Slide-in menu
          if (_showMenu)
            GestureDetector(
              onTap: () => setState(() => _showMenu = false),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),

          // Edit profile sheet
          if (_showEdit)
            GestureDetector(
              onTap: () => setState(() => _showEdit = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_showEdit)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _EditProfileSheet(
                nameCtrl: _editNameCtrl,
                usernameCtrl: _editUsernameCtrl,
                bioCtrl: _editBioCtrl,
                currentAvatarUrl: userData['avatarUrl'],
                saving: _saving,
                onPickAvatar: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => _newAvatar = File(picked.path));
                  }
                },
                newAvatar: _newAvatar,
                onSave: _saveProfile,
                onCancel: () => setState(() => _showEdit = false),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _editNameCtrl.dispose();
    _editUsernameCtrl.dispose();
    _editBioCtrl.dispose();
    super.dispose();
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? const Color(0xFF262626), size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: color ?? const Color(0xFF262626),
        ),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: Color(0xFF8E8E8E), size: 20),
    );
  }
}

class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController bioCtrl;
  final String? currentAvatarUrl;
  final File? newAvatar;
  final bool saving;
  final VoidCallback onPickAvatar;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.usernameCtrl,
    required this.bioCtrl,
    required this.currentAvatarUrl,
    required this.newAvatar,
    required this.saving,
    required this.onPickAvatar,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF262626)))),
              const Text('Edit Profile',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              TextButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0095F6)),
                      )
                    : const Text('Done',
                        style: TextStyle(
                            color: Color(0xFF0095F6),
                            fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickAvatar,
            child: Stack(
              children: [
                newAvatar != null
                    ? CircleAvatar(
                        radius: 40,
                        backgroundImage: FileImage(newAvatar!))
                    : AvatarWidget(
                        url: currentAvatarUrl,
                        name: nameCtrl.text,
                        size: 80),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: Color(0xFF0095F6),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _field(nameCtrl, 'Full Name'),
          const SizedBox(height: 8),
          _field(usernameCtrl, 'Username'),
          const SizedBox(height: 8),
          _field(bioCtrl, 'Bio', maxLines: 3),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDBDBDB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDBDBDB))),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

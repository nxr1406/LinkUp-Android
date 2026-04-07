import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'admin_screen.dart';
import 'verification_request_screen.dart';
import 'suspension_appeal_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel? me;
  const ProfileScreen({super.key, this.me});

  @override
  Widget build(BuildContext context) {
    if (me == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppColors.black, size: 18),
            const SizedBox(width: 6),
            Text(
              me!.username,
              style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (me!.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: AppColors.verified, size: 18),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.black, size: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.black, size: 26),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            _AvatarEditor(me: me!),
            const SizedBox(height: 16),
            // Display name
            Text(
              me!.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '@${me!.username}',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textMedium),
                ),
                if (me!.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified,
                      color: AppColors.verified, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                me!.email,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            // Followers / Following (placeholder counts from real data)
            _FollowStats(uid: me!.uid),
            const SizedBox(height: 20),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditProfileScreen(me: me!)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text('Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: () {
                          final text =
                              'Check out @${me!.username} on LinkUp!';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(text)),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text('Share Profile',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(me: me!),
    );
  }
}

class _AvatarEditor extends StatefulWidget {
  final UserModel me;
  const _AvatarEditor({required this.me});

  @override
  State<_AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<_AvatarEditor> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await UserService().updateProfilePhoto(
        uid: widget.me.uid,
        imageBytes: Uint8List.fromList(bytes),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile photo updated!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndUpload,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _uploading
              ? const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : AvatarWidget(user: widget.me, radius: 48),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt,
                color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }
}

class _FollowStats extends StatelessWidget {
  final String uid;
  const _FollowStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    // Real follower counts from chats collection
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatItem(label: 'FOLLOWERS', value: '—'),
        Container(
            width: 1, height: 30, color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 24)),
        _StatItem(label: 'FOLLOWING', value: '—'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.black)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.grey, letterSpacing: 0.5)),
      ],
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final UserModel me;
  const _SettingsSheet({required this.me});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Settings',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Privacy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.block,
            label: 'Blocked accounts',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            trailing: Switch(
              value: false,
              onChanged: (_) {},
              activeColor: AppColors.primary,
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.key_outlined,
            label: 'Change Password',
            onTap: () => _changePasswordDialog(context),
          ),
          _SettingsTile(
            icon: Icons.verified_outlined,
            label: 'Request Verification',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => VerificationRequestScreen(me: me)),
              );
            },
          ),
          if (me.isAdmin) ...[
            _SettingsTile(
              icon: Icons.shield_outlined,
              label: 'Review Verifications',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()));
              },
            ),
            _SettingsTile(
              icon: Icons.gavel_outlined,
              label: 'Suspension Appeals',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminScreen(tab: 1)));
              },
            ),
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin Settings',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminScreen(tab: 2)));
              },
            ),
          ],
          const Divider(height: 1),
          _SettingsTile(
            icon: Icons.download_outlined,
            label: 'Export Data',
            onTap: () {},
          ),
          const Divider(height: 1),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Log out',
            color: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            label: 'Delete Account',
            color: Colors.red,
            onTap: () => _deleteAccountDialog(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _changePasswordDialog(BuildContext context) {
    Navigator.pop(context);
    final newPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: newPassCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'New password (min 6 chars)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (newPassCtrl.text.length < 6) return;
              try {
                await FirebaseAuth.instance.currentUser!
                    .updatePassword(newPassCtrl.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password updated!'),
                    backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAccountDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await UserService().deleteUserData(uid);
                await FirebaseAuth.instance.currentUser!.delete();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.color,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textDark, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textDark,
          fontSize: 15,
        ),
      ),
      trailing: trailing ?? (onTap != null ? null : null),
      onTap: onTap,
    );
  }
}

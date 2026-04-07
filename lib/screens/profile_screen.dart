import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../main.dart';
import '../widgets/avatar_widget.dart';
import 'admin_screen.dart';
import 'verification_request_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel? me;
  const ProfileScreen({super.key, this.me});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (me == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg(dark),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(dark),
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg(dark),
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          Icon(Icons.lock_outline, color: AppColors.textPrimary(dark), size: 18),
          const SizedBox(width: 6),
          Text(me!.username,
              style: TextStyle(
                  color: AppColors.textPrimary(dark),
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          if (me!.isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: AppColors.verified, size: 18),
          ],
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.textPrimary(dark), size: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.menu, color: AppColors.textPrimary(dark), size: 26),
            onPressed: () => _showSettings(context, dark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 20),
          _AvatarEditor(me: me!),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(me!.displayName,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(dark))),
            if (me!.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: AppColors.verified, size: 20),
            ],
          ]),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('@${me!.username}',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary(dark))),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(me!.email,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark)),
                textAlign: TextAlign.center),
          ),
          if (me!.bio != null && me!.bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(me!.bio!,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary(dark)),
                  textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StatItem(label: 'FOLLOWERS', value: '—', dark: dark),
            Container(width: 1, height: 30,
                color: AppColors.divider(dark),
                margin: const EdgeInsets.symmetric(horizontal: 24)),
            _StatItem(label: 'FOLLOWING', value: '—', dark: dark),
          ]),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => EditProfileScreen(me: me!))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary(dark),
                      foregroundColor: dark ? AppColors.darkBackground : Colors.white,
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
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(dark),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: AppColors.divider(dark)),
                    ),
                    child: const Text('Share Profile',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  void _showSettings(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(dark),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(me: me!),
    );
  }
}

// ── Avatar editor ─────────────────────────────────────────────────────────────
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
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await UserService().updateProfilePhoto(
          uid: widget.me.uid, imageBytes: Uint8List.fromList(bytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndUpload,
      child: Stack(alignment: Alignment.bottomRight, children: [
        _uploading
            ? const CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : AvatarWidget(user: widget.me, radius: 48),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
        ),
      ]),
    );
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label, value;
  final bool dark;
  const _StatItem({required this.label, required this.value, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(dark))),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(dark),
              letterSpacing: 0.5)),
    ]);
  }
}

// ── Settings bottom sheet ─────────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final UserModel me;
  const _SettingsSheet({required this.me});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _darkMode = LinkUpApp.isDark;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.textPrimary(dark);
    final subColor = AppColors.textSecondary(dark);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
                color: AppColors.divider(dark),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Settings',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
          ),

          // ── Normal settings ──────────────────────────────────
          _Tile(icon: Icons.notifications_outlined, label: 'Notifications',
              dark: dark, onTap: () {}),
          _Tile(icon: Icons.lock_outline, label: 'Privacy',
              dark: dark, onTap: () {}),
          _Tile(icon: Icons.block, label: 'Blocked accounts',
              dark: dark, onTap: () {}),

          // Dark mode toggle
          ListTile(
            leading: Icon(Icons.dark_mode_outlined, color: textColor, size: 22),
            title: Text('Dark Mode',
                style: TextStyle(color: textColor, fontSize: 15)),
            trailing: Switch(
              value: _darkMode,
              onChanged: (v) {
                setState(() => _darkMode = v);
                LinkUpApp.toggleTheme();
              },
              activeColor: AppColors.primary,
            ),
          ),

          _Tile(icon: Icons.key_outlined, label: 'Change Password',
              dark: dark, onTap: () => _changePasswordDialog(context)),

          _Tile(icon: Icons.verified_outlined, label: 'Request Verification',
              dark: dark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            VerificationRequestScreen(me: widget.me)));
              }),

          // ── Admin-only section ────────────────────────────────
          if (widget.me.isAdmin) ...[
            Divider(height: 1, color: AppColors.divider(dark)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(Icons.admin_panel_settings,
                    color: AppColors.verified, size: 16),
                const SizedBox(width: 6),
                Text('Admin Panel',
                    style: TextStyle(
                        color: AppColors.verified,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ]),
            ),
            _Tile(
              icon: Icons.shield_outlined,
              label: 'Review Verifications',
              color: AppColors.verified,
              dark: dark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen(tab: 0)));
              },
            ),
            _Tile(
              icon: Icons.gavel_outlined,
              label: 'Suspension Appeals',
              color: AppColors.verified,
              dark: dark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen(tab: 1)));
              },
            ),
            _Tile(
              icon: Icons.manage_accounts_outlined,
              label: 'Manage Users',
              color: AppColors.verified,
              dark: dark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen(tab: 2)));
              },
            ),
            Divider(height: 1, color: AppColors.divider(dark)),
          ],

          // ── Danger zone ──────────────────────────────────────
          if (!widget.me.isAdmin)
            Divider(height: 1, color: AppColors.divider(dark)),

          _Tile(icon: Icons.download_outlined, label: 'Export Data',
              dark: dark, onTap: () {}),

          Divider(height: 1, color: AppColors.divider(dark)),

          _Tile(
            icon: Icons.logout,
            label: 'Log out',
            color: Colors.red,
            dark: dark,
            onTap: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
          ),
          _Tile(
            icon: Icons.delete_outline,
            label: 'Delete Account',
            color: Colors.red,
            dark: dark,
            onTap: () => _deleteAccountDialog(context),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _changePasswordDialog(BuildContext context) {
    Navigator.pop(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final dark = LinkUpApp.isDark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg(dark),
        title: Text('Change Password',
            style: TextStyle(color: AppColors.textPrimary(dark))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: currentCtrl,
            obscureText: true,
            style: TextStyle(color: AppColors.textPrimary(dark)),
            decoration: InputDecoration(
              hintText: 'Current password',
              hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
              filled: true,
              fillColor: AppColors.inputFill(dark),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newCtrl,
            obscureText: true,
            style: TextStyle(color: AppColors.textPrimary(dark)),
            decoration: InputDecoration(
              hintText: 'New password (min 6 chars)',
              hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
              filled: true,
              fillColor: AppColors.inputFill(dark),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (currentCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter your current password'),
                    backgroundColor: Colors.red));
                return;
              }
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('New password must be at least 6 characters'),
                    backgroundColor: Colors.red));
                return;
              }
              try {
                final user = FirebaseAuth.instance.currentUser!;
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentCtrl.text,
                );
                // Re-authenticate with current password
                await user.reauthenticateWithCredential(credential);
                // Now update to new password
                await user.updatePassword(newCtrl.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password updated!'),
                    backgroundColor: Colors.green));
              } on FirebaseAuthException catch (e) {
                String msg = 'Error updating password';
                if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                  msg = 'Current password is incorrect';
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(msg), backgroundColor: Colors.red));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Update',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAccountDialog(BuildContext context) {
    Navigator.pop(context);
    final dark = LinkUpApp.isDark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg(dark),
        title: Text('Delete Account',
            style: TextStyle(color: AppColors.textPrimary(dark))),
        content: Text(
            'This will permanently delete your account and all data.',
            style: TextStyle(color: AppColors.textSecondary(dark))),
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable settings tile ────────────────────────────────────────────────────
class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool dark;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.dark,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary(dark);
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontSize: 15)),
      onTap: onTap,
    );
  }
}

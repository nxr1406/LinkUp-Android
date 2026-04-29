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
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_screen.dart';
import 'blocked_accounts_screen.dart';
import 'app_lock_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel? me;
  const ProfileScreen({super.key, this.me});

  @override
  Widget build(BuildContext context) {
    const dark = false;

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
          Icon(Icons.lock_rounded,
              color: AppColors.textPrimary(dark), size: 18),
          const SizedBox(width: 6),
          Text(me!.username,
              style: TextStyle(
                  color: AppColors.textPrimary(dark),
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          if (me!.isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded, color: AppColors.verified, size: 18),
          ],
          if (me!.isAdmin) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.verified.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Admin',
                  style: TextStyle(
                      color: AppColors.verified,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.tune_rounded,
                color: AppColors.textPrimary(dark), size: 26),
            onPressed: () => _showSettings(context, dark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 24),
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
              const Icon(Icons.verified_rounded, color: AppColors.verified, size: 20),
            ],
          ]),
          const SizedBox(height: 4),
          Text('@${me!.username}',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary(dark))),
          const SizedBox(height: 6),
          Text(me!.email,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary(dark))),
          if (me!.bio != null && me!.bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                me!.bio!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary(dark)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Stats row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StatItem(label: 'FOLLOWERS', value: '—', dark: dark),
            Container(
                width: 1,
                height: 30,
                color: AppColors.divider(dark),
                margin: const EdgeInsets.symmetric(horizontal: 24)),
            _StatItem(label: 'FOLLOWING', value: '—', dark: dark),
          ]),
          const SizedBox(height: 20),
          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EditProfileScreen(me: me!))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary(dark),
                      foregroundColor:
                          Colors.white,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

  Future<void> _pick() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
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
      onTap: _pick,
      child: Stack(alignment: Alignment.bottomRight, children: [
        _uploading
            ? const CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : AvatarWidget(user: widget.me, radius: 48),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 14),
        ),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final bool dark;
  const _StatItem(
      {required this.label, required this.value, required this.dark});

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
  @override
  Widget build(BuildContext context) {
    const dark = false;
    final tc = AppColors.textPrimary(dark);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
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
                    color: tc)),
          ),

          // ── General ─────────────────────────────────────────
          _T(icon: Icons.notifications_none_rounded, label: 'Notifications',
              dark: dark, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen()));
          }),
          _T(icon: Icons.security_rounded, label: 'Privacy & Terms',
              dark: dark, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const PrivacyScreen()));
          }),
          _T(icon: Icons.block_rounded, label: 'Blocked Accounts', dark: dark,
              onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const BlockedAccountsScreen()));
          }),

          // App Lock
          AppLockSettingsTile(dark: dark),


          _T(icon: Icons.key_rounded, label: 'Change Password',
              dark: dark, onTap: () => _changePassword(context, dark)),

          _T(icon: Icons.verified_rounded, label: 'Request Verification',
              dark: dark, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => VerificationRequestScreen(me: widget.me)));
          }),

          // ── Admin-only panel ─────────────────────────────────
          if (widget.me.isAdmin) ...[
            Divider(height: 1, color: AppColors.divider(dark)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.verified, size: 16),
                const SizedBox(width: 6),
                Text('ADMIN PANEL',
                    style: const TextStyle(
                        color: AppColors.verified,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0)),
              ]),
            ),
            _T(icon: Icons.shield_rounded,
                label: 'Review Verifications',
                color: AppColors.verified,
                dark: dark, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminScreen(tab: 0)));
            }),
            _T(icon: Icons.gavel_rounded,
                label: 'Suspension Appeals',
                color: AppColors.verified,
                dark: dark, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminScreen(tab: 1)));
            }),
            _T(icon: Icons.manage_accounts_rounded,
                label: 'Manage Users',
                color: AppColors.verified,
                dark: dark, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminScreen(tab: 2)));
            }),
          ],

          Divider(height: 1, color: AppColors.divider(dark)),

          _T(icon: Icons.logout_rounded, label: 'Log out',
              color: Colors.red, dark: dark, onTap: () async {
            Navigator.pop(context);
            await AuthService().signOut();
          }),
          _T(icon: Icons.delete_outline_rounded, label: 'Delete Account',
              color: Colors.red, dark: dark,
              onTap: () => _deleteAccount(context, dark)),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _changePassword(BuildContext ctx, bool dark) {
    Navigator.pop(ctx);
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password',
            style: TextStyle(color: Color(0xFF111111))),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          style: const TextStyle(color: Color(0xFF111111)),
          decoration: InputDecoration(
            hintText: 'New password (min 6 chars)',
            hintStyle: const TextStyle(color: Color(0xFF888888)),
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF666666)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () async {
              if (ctrl.text.length < 6) return;
              try {
                await FirebaseAuth.instance.currentUser!
                    .updatePassword(ctrl.text);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Password updated!'),
                    backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('$e'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Update',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext ctx, bool dark) {
    Navigator.pop(ctx);
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account',
            style: TextStyle(color: Color(0xFF111111))),
        content: const Text('Permanently deletes your account & all data.',
            style: TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF666666)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final uid =
                    FirebaseAuth.instance.currentUser!.uid;
                await UserService().deleteUserData(uid);
                await FirebaseAuth.instance.currentUser!.delete();
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('$e'),
                    backgroundColor: Colors.red));
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

class _T extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool dark;
  final VoidCallback? onTap;

  const _T({
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

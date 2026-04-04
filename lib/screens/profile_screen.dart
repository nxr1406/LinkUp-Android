import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';
import '../services/catbox_service.dart';
import 'admin_verification_screen.dart';
import 'admin_appeals_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<LinkUpAuthProvider>();
    final userData = auth.userData;
    if (userData == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isAdmin = userData['role'] == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Icon(Icons.lock_outline, size: 16, color: textPrimary),
          const SizedBox(width: 4),
          Text(userData['username'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary)),
          if (userData['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
        ]),
        actions: [
          IconButton(onPressed: () => context.go('/app/search'), icon: Icon(Icons.add, size: 28, color: textPrimary)),
          IconButton(onPressed: () => _showSettingsSheet(context, auth, userData, isAdmin),
              icon: Icon(Icons.menu, size: 28, color: textPrimary)),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(0.5),
            child: Divider(height: 0.5, color: divClr)),
      ),
      body: SingleChildScrollView(child: Column(children: [
        const SizedBox(height: 20),
        Center(child: AvatarWidget(url: getAvatarUrl(userData, isCurrentUser: true), name: userData['fullName'] ?? '', size: 80)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(userData['fullName'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary)),
          if (userData['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
        ]),
        const SizedBox(height: 2),
        Text('@${userData['username'] ?? ''}', style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
        if ((userData['bio'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(userData['bio'], textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textPrimary))),
        ],
        const SizedBox(height: 16),
        // Stats
        Builder(builder: (context) {
          final ud = context.watch<LinkUpAuthProvider>().userData;
          final followers = (ud?['followers'] as List?)?.length ?? 0;
          final following = (ud?['following'] as List?)?.length ?? 0;
          return IntrinsicHeight(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StatItem(count: followers, label: 'FOLLOWERS'),
            Container(width: 1, height: 32, color: divClr, margin: const EdgeInsets.symmetric(horizontal: 24)),
            _StatItem(count: following, label: 'FOLLOWING'),
          ]));
        }),
        const SizedBox(height: 16),
        // Buttons — matches screenshot: Edit=white/dark-text, Share=dark-fill/white-text in dark mode
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: _ActionButton(label: 'Edit Profile', isDark: isDark,
                onTap: () => _showEditSheet(context, auth, userData))),
            const SizedBox(width: 8),
            Expanded(child: _ActionButton(label: 'Share Profile', isDark: isDark, onTap: () {})),
          ])),
        const SizedBox(height: 40),
      ])),
    );
  }

  void _showSettingsSheet(BuildContext context, LinkUpAuthProvider auth, Map userData, bool isAdmin) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => _SettingsSheet(auth: auth, userData: userData, isAdmin: isAdmin));
  }

  void _showEditSheet(BuildContext context, LinkUpAuthProvider auth, Map userData) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => _EditProfileSheet(userData: userData));
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  const _StatItem({required this.count, required this.label});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF262626))),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E), fontWeight: FontWeight.w500)),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    // Dark mode: Edit=white bg/black text, Share=dark surface/white text
    // Light mode: Edit=black bg/white text, Share=light gray bg/black text
    final bool isEdit = label == 'Edit Profile';
    final bgColor = isDark
        ? (isEdit ? Colors.white : const Color(0xFF2C2C2E))
        : (isEdit ? const Color(0xFF262626) : const Color(0xFFF0F0F0));
    final textColor = isDark
        ? (isEdit ? Colors.black : Colors.white)
        : (isEdit ? Colors.white : const Color(0xFF262626));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }
}

// ===== Settings Sheet =====
class _SettingsSheet extends StatelessWidget {
  final LinkUpAuthProvider auth;
  final Map userData;
  final bool isAdmin;
  const _SettingsSheet({required this.auth, required this.userData, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    final avatarUrl = getAvatarUrl(userData as Map<String, dynamic>?, isCurrentUser: true);

    return Container(
      decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Profile pic preview at top of sheet
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: AvatarWidget(url: avatarUrl, name: userData['fullName'] ?? '', size: 56),
        ),
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: divClr, borderRadius: BorderRadius.circular(2)))),
        Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 4),

        _item(context, Icons.notifications_outlined, 'Notifications', textPrimary, divClr,
            onTap: () { Navigator.pop(context); context.go('/app/notifications'); }),
        _div(divClr),
        _item(context, Icons.lock_outline, 'Privacy', textPrimary, divClr,
            onTap: () { Navigator.pop(context); context.go('/app/privacy'); }),
        _div(divClr),
        _item(context, Icons.block, 'Blocked accounts', textPrimary, divClr,
            onTap: () { Navigator.pop(context); context.go('/app/blocked'); }),
        _div(divClr),
        // Dark Mode Toggle
        Consumer<ThemeProvider>(builder: (context, theme, _) => ListTile(
          dense: true,
          leading: Icon(Icons.settings_outlined, color: textPrimary, size: 22),
          title: Text('Dark Mode', style: TextStyle(fontSize: 15, color: textPrimary)),
          trailing: Switch(
            value: theme.isDark,
            onChanged: (_) => theme.toggle(),
            activeColor: const Color(0xFF0095F6),
            trackColor: MaterialStateProperty.resolveWith((s) =>
                s.contains(MaterialState.selected)
                    ? const Color(0xFF0095F6).withOpacity(0.4)
                    : isDark ? const Color(0xFF48484A) : const Color(0xFFDBDBDB)),
          ),
        )),
        _div(divClr),
        _item(context, Icons.key_outlined, 'Change Password', textPrimary, divClr,
            onTap: () { Navigator.pop(context); _showChangePassword(context); }),
        _div(divClr),
        _item(context, Icons.verified_outlined, 'Request Verification', textPrimary, divClr,
            onTap: () { Navigator.pop(context); _showVerification(context); }),
        if (isAdmin) ...[
          _div(divClr),
          _item(context, Icons.shield_outlined, 'Review Verifications', textPrimary, divClr,
              isAdmin: true, onTap: () { Navigator.pop(context); _openAdminSheet(context, const AdminVerificationScreen()); }),
          _div(divClr),
          _item(context, Icons.gavel_outlined, 'Suspension Appeals', textPrimary, divClr,
              isAdmin: true, onTap: () { Navigator.pop(context); _openAdminSheet(context, const AdminAppealsScreen()); }),
          _div(divClr),
          _item(context, Icons.admin_panel_settings_outlined, 'Admin Settings', textPrimary, divClr,
              isAdmin: true, onTap: () { Navigator.pop(context); _showAdminSettings(context); }),
        ],
        _div(divClr),
        _item(context, Icons.download_outlined, 'Export Data', textPrimary, divClr, onTap: () {}),
        _div(divClr),
        _item(context, Icons.logout, 'Log out', textPrimary, divClr,
            color: const Color(0xFFED4956), onTap: () async {
          Navigator.pop(context);
          await auth.signOut();
          if (context.mounted) context.go('/login');
        }),
        _div(divClr),
        _item(context, Icons.delete_outline, 'Delete Account', textPrimary, divClr,
            color: const Color(0xFFED4956), onTap: () {}),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _item(BuildContext ctx, IconData icon, String label, Color textPrimary, Color divClr,
      {Color? color, bool isAdmin = false, required VoidCallback onTap}) {
    final c = color ?? (isAdmin ? const Color(0xFF0095F6) : textPrimary);
    return ListTile(dense: true, onTap: onTap,
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(fontSize: 15, color: c, fontWeight: isAdmin ? FontWeight.w600 : FontWeight.w400)));
  }

  Widget _div(Color color) => Divider(height: 0, color: color, indent: 16);

  void _openAdminSheet(BuildContext context, Widget screen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: screen));
  }

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => const _ChangePasswordSheet());
  }

  void _showVerification(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => _VerificationSheet(userData: userData));
  }

  void _showAdminSettings(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => const _AdminSettingsSheet());
  }
}

// ===== Edit Profile Sheet =====
class _EditProfileSheet extends StatefulWidget {
  final Map userData;
  const _EditProfileSheet({required this.userData});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _nameCtrl = TextEditingController(text: widget.userData['fullName'] ?? '');
  late final _usernameCtrl = TextEditingController(text: widget.userData['username'] ?? '');
  late final _bioCtrl = TextEditingController(text: widget.userData['bio'] ?? '');
  File? _newAvatar;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: divClr, width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, size: 24, color: textPrimary)),
            Text('Edit profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
            GestureDetector(
              onTap: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2))
                  : const Icon(Icons.check, color: Color(0xFF0095F6), size: 24),
            ),
          ])),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Column(children: [
                _newAvatar != null
                    ? CircleAvatar(radius: 40, backgroundImage: FileImage(_newAvatar!))
                    : AvatarWidget(url: getAvatarUrl(widget.userData as Map<String, dynamic>?, isCurrentUser: true),
                        name: widget.userData['fullName'] ?? '', size: 80),
                const SizedBox(height: 8),
                const Text('Change photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0095F6))),
              ]),
            ),
            const SizedBox(height: 24),
            _field(_nameCtrl, 'Name', isDark, textPrimary, divClr),
            _field(_usernameCtrl, 'Username', isDark, textPrimary, divClr),
            _field(_bioCtrl, 'Bio', isDark, textPrimary, divClr),
          ]),
        )),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, bool isDark, Color textPrimary, Color divClr) {
    return Padding(padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 16, color: textPrimary),
          decoration: InputDecoration(
            border: UnderlineInputBorder(borderSide: BorderSide(color: divClr)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: divClr)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: textPrimary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 8), isDense: true,
          ),
        ),
      ]));
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      String? avatarUrl;
      if (_newAvatar != null) avatarUrl = await CatboxService.uploadFile(_newAvatar!);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'bio': _bioCtrl.text.trim(),
        if (avatarUrl != null) ...{
          'avatarUrl': avatarUrl,
          'photoURL': avatarUrl,
        },
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {} finally { if (mounted) setState(() => _saving = false); }
  }
}

// ===== Change Password Sheet =====
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    final canSave = _curCtrl.text.isNotEmpty && _newCtrl.text.length >= 6 && _newCtrl.text == _confCtrl.text;

    return Container(
      decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: divClr, width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, size: 24, color: textPrimary)),
            Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
            GestureDetector(
              onTap: canSave && !_saving ? _change : null,
              child: Icon(Icons.check, color: canSave ? const Color(0xFF0095F6) : const Color(0xFF48484A), size: 24),
            ),
          ])),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _passField(_curCtrl, 'Current Password', textPrimary, divClr),
          _passField(_newCtrl, 'New Password', textPrimary, divClr),
          _passField(_confCtrl, 'Confirm New Password', textPrimary, divClr),
        ])),
      ]),
    );
  }

  Widget _passField(TextEditingController ctrl, String label, Color textPrimary, Color divClr) {
    return Padding(padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        TextField(
          controller: ctrl, obscureText: true,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 16, color: textPrimary),
          decoration: InputDecoration(
            border: UnderlineInputBorder(borderSide: BorderSide(color: divClr)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: divClr)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: textPrimary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 8), isDense: true,
          ),
        ),
      ]));
  }

  Future<void> _change() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(email: user.email!, password: _curCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newCtrl.text);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed. Check current password.'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }
}

// ===== Verification Sheet =====
class _VerificationSheet extends StatefulWidget {
  final Map userData;
  const _VerificationSheet({required this.userData});
  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  final _linkCtrl = TextEditingController();
  String _category = 'creator';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    final inputBorder = OutlineInputBorder(borderSide: BorderSide(color: divClr));
    final isVerified = widget.userData['isVerified'] == true;
    final isPending = widget.userData['verificationStatus'] == 'pending';

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: divClr, width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, size: 24, color: textPrimary)),
            Text('Request Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
            if (!isVerified && !isPending)
              GestureDetector(
                onTap: _linkCtrl.text.isNotEmpty && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2))
                    : Icon(Icons.check, color: _linkCtrl.text.isNotEmpty ? const Color(0xFF0095F6) : const Color(0xFF48484A), size: 24),
              )
            else const SizedBox(width: 24),
          ])),
        Expanded(child: isVerified
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.verified, color: Color(0xFF0095F6), size: 64),
              const SizedBox(height: 12),
              Text('You are verified', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
              const SizedBox(height: 8),
              const Text('Your account has a verified badge.', style: TextStyle(color: Color(0xFF8E8E8E))),
            ]))
          : isPending
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.shield, color: Color(0xFF8E8E8E), size: 64),
              const SizedBox(height: 12),
              Text('Request Pending', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
              const SizedBox(height: 8),
              const Text('We are reviewing your request.', style: TextStyle(color: Color(0xFF8E8E8E))),
            ]))
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('A verified badge confirms your account is the authentic presence of a notable public figure.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
              const SizedBox(height: 20),
              Text('Step 1: Confirm authenticity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 12),
              const Text('Google Drive PDF Link', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              TextField(
                controller: _linkCtrl, onChanged: (_) => setState(() {}),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://drive.google.com/file/d/...',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
                  border: inputBorder, enabledBorder: inputBorder,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
              const SizedBox(height: 20),
              Text('Step 2: Select category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(border: inputBorder, enabledBorder: inputBorder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: 'creator', child: Text('Digital Creator/Influencer')),
                  DropdownMenuItem(value: 'news', child: Text('News/Media')),
                  DropdownMenuItem(value: 'sports', child: Text('Sports')),
                  DropdownMenuItem(value: 'music', child: Text('Music')),
                  DropdownMenuItem(value: 'business', child: Text('Business/Brand')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
            ]))),
      ]),
    );
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('verificationRequests').add({
        'userId': uid, 'username': widget.userData['username'],
        'fullName': widget.userData['fullName'],
        'avatarUrl': getAvatarUrl(widget.userData as Map<String, dynamic>?, isCurrentUser: true),
        'link': _linkCtrl.text.trim(), 'category': _category,
        'status': 'pending', 'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'verificationStatus': 'pending'});
      if (mounted) Navigator.pop(context);
    } catch (_) {} finally { if (mounted) setState(() => _submitting = false); }
  }
}

// ===== Admin Settings Sheet =====
class _AdminSettingsSheet extends StatefulWidget {
  const _AdminSettingsSheet();
  @override
  State<_AdminSettingsSheet> createState() => _AdminSettingsSheetState();
}

class _AdminSettingsSheetState extends State<_AdminSettingsSheet> {
  Map<String, double> _storage = {'used': 0, 'free': 1024, 'total': 1024};
  bool _loading = true;
  String _deleteText = '';
  bool _deleting = false;

  @override
  void initState() { super.initState(); _fetchStorage(); }

  Future<void> _fetchStorage() async {
    try {
      final chats = await FirebaseFirestore.instance.collection('chats').get();
      final users = await FirebaseFirestore.instance.collection('users').get();
      double total = chats.size * 1024 + users.size * 2048;
      final usedMB = total / (1024 * 1024);
      setState(() { _storage = {'used': usedMB, 'free': 1024 - usedMB, 'total': 1024}; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final divClr = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: divClr, width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, size: 24, color: textPrimary)),
            Text('Admin Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
            const SizedBox(width: 24),
          ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.storage, size: 20, color: textPrimary), const SizedBox(width: 8),
            Text('Storage Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary))]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Used: ${_storage['used']!.toStringAsFixed(2)} MB', style: TextStyle(fontWeight: FontWeight.w500, color: textPrimary)),
                Text('Free: ${_storage['free']!.toStringAsFixed(0)} MB', style: const TextStyle(color: Color(0xFF8E8E8E))),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_storage['used']! / _storage['total']!).clamp(0.0, 1.0),
                  backgroundColor: divClr, color: const Color(0xFF0095F6), minHeight: 8)),
            ])),
          const SizedBox(height: 24),
          Divider(color: divClr),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.delete, size: 20, color: Color(0xFFED4956)), const SizedBox(width: 8),
            const Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFED4956)))]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A1C1E) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF5A2C2E) : Colors.red.shade100)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Clear All Chats', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFED4956))),
              const SizedBox(height: 4),
              const Text('Permanently delete all chats and messages for all users.', style: TextStyle(fontSize: 12, color: Color(0xFFED4956))),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _deleteText = v),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type "sudo delete chat-all"',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
                  border: OutlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFF5A2C2E) : Colors.red.shade200)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _deleteText == 'sudo delete chat-all' && !_deleting ? _deleteAll : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED4956), disabledBackgroundColor: Colors.red.shade200),
                child: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete All Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              )),
            ])),
        ]))),
      ]),
    );
  }

  Future<void> _deleteAll() async {
    setState(() => _deleting = true);
    try {
      final chats = await FirebaseFirestore.instance.collection('chats').get();
      for (final chat in chats.docs) {
        final msgs = await FirebaseFirestore.instance.collection('messages/${chat.id}/msgs').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final m in msgs.docs) batch.delete(m.reference);
        await batch.commit();
        await chat.reference.delete();
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {} finally { if (mounted) setState(() => _deleting = false); }
  }
}

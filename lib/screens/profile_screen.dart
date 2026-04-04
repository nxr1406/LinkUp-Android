import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
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
  int _chatCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChatCount();
  }

  Future<void> _loadChatCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final q = await FirebaseFirestore.instance.collection('chats')
        .where('participants', arrayContains: uid).get();
    if (mounted) setState(() => _chatCount = q.size);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<LinkUpAuthProvider>();
    final userData = auth.userData;
    if (userData == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isAdmin = userData['role'] == 'admin';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF262626)),
          const SizedBox(width: 4),
          Text(userData['username'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF262626))),
          if (userData['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
        ]),
        actions: [
          IconButton(onPressed: () => context.go('/app/search'), icon: const Icon(Icons.add, size: 28, color: Color(0xFF262626))),
          IconButton(onPressed: () => _showSettingsSheet(context, auth, userData, isAdmin), icon: const Icon(Icons.menu, size: 28, color: Color(0xFF262626))),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(0.5), child: Divider(height: 0.5, color: Color(0xFFDBDBDB))),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 20),
          // Avatar
          Center(child: AvatarWidget(url: userData['avatarUrl'], name: userData['fullName'] ?? '', size: 80)),
          const SizedBox(height: 12),
          // Full name + verified
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(userData['fullName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF262626))),
            if (userData['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
          ]),
          const SizedBox(height: 2),
          Text('@${userData['username'] ?? ''}', style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
          if ((userData['bio'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(userData['bio'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF262626))),
            ),
          ],
          const SizedBox(height: 16),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IntrinsicHeight(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StatItem(count: _chatCount, label: 'CHATS'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _ActionButton(label: 'Edit Profile', onTap: () => _showEditSheet(context, auth, userData))),
              const SizedBox(width: 8),
              Expanded(child: _ActionButton(label: 'Share Profile', onTap: () {})),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, LinkUpAuthProvider auth, Map userData, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(auth: auth, userData: userData, isAdmin: isAdmin),
    );
  }

  void _showEditSheet(BuildContext context, LinkUpAuthProvider auth, Map userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(userData: userData),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  const _StatItem({required this.count, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF262626))),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E), fontWeight: FontWeight.w500)),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: label == 'Edit Profile' ? const Color(0xFF262626) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: label == 'Edit Profile' ? Colors.white : const Color(0xFF262626),
        )),
      ),
    );
  }
}

// ===== Settings Bottom Sheet =====
class _SettingsSheet extends StatefulWidget {
  final LinkUpAuthProvider auth;
  final Map userData;
  final bool isAdmin;
  const _SettingsSheet({required this.auth, required this.userData, required this.isAdmin});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFDBDBDB), borderRadius: BorderRadius.circular(2)))),
        const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF262626))),
        const SizedBox(height: 8),
        _settingItem(Icons.notifications_outlined, 'Notifications', onTap: () { Navigator.pop(context); }),
        _divider(),
        _settingItem(Icons.lock_outline, 'Privacy', onTap: () { Navigator.pop(context); }),
        _divider(),
        _settingItem(Icons.block, 'Blocked accounts', onTap: () { Navigator.pop(context); context.go('/app/blocked'); }),
        _divider(),
        _settingItemToggle(Icons.settings_outlined, 'Dark Mode', _darkMode, (val) => setState(() => _darkMode = val)),
        _divider(),
        _settingItem(Icons.key_outlined, 'Change Password', onTap: () { Navigator.pop(context); _showChangePassword(context); }),
        _divider(),
        _settingItem(Icons.verified_outlined, 'Request Verification', onTap: () { Navigator.pop(context); _showVerification(context); }),
        if (widget.isAdmin) ...[
          _divider(),
          _settingItem(Icons.shield_outlined, 'Review Verifications', isAdmin: true,
              onTap: () { Navigator.pop(context); _openAdminSheet(context, const AdminVerificationScreen()); }),
          _divider(),
          _settingItem(Icons.gavel_outlined, 'Suspension Appeals', isAdmin: true,
              onTap: () { Navigator.pop(context); _openAdminSheet(context, const AdminAppealsScreen()); }),
          _divider(),
          _settingItem(Icons.admin_panel_settings_outlined, 'Admin Settings', isAdmin: true,
              onTap: () { Navigator.pop(context); _showAdminSettings(context); }),
        ],
        _divider(),
        _settingItem(Icons.download_outlined, 'Export Data', onTap: () {}),
        _divider(),
        _settingItem(Icons.logout, 'Log out', color: const Color(0xFFED4956), onTap: () async {
          Navigator.pop(context);
          await widget.auth.signOut();
          if (context.mounted) context.go('/login');
        }),
        _divider(),
        _settingItem(Icons.delete_outline, 'Delete Account', color: const Color(0xFFED4956), onTap: () {}),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _settingItem(IconData icon, String label, {Color? color, bool isAdmin = false, required VoidCallback onTap}) {
    final c = color ?? (isAdmin ? const Color(0xFF0095F6) : const Color(0xFF262626));
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(fontSize: 15, color: c, fontWeight: isAdmin ? FontWeight.w600 : FontWeight.w400)),
      dense: true,
    );
  }

  Widget _settingItemToggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF262626), size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF262626))),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF0095F6)),
      dense: true,
    );
  }

  Widget _divider() => const Divider(height: 0, color: Color(0xFFDBDBDB), indent: 16);

  void _openAdminSheet(BuildContext context, Widget screen) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: screen,
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => const _ChangePasswordSheet());
  }

  void _showVerification(BuildContext context) {
    final userData = widget.userData;
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 52,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDBDBDB), width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 24, color: Color(0xFF262626))),
            const Text('Edit profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2))
                  : const Icon(Icons.check, color: Color(0xFF0095F6), size: 24),
            ),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Avatar
            GestureDetector(
              onTap: _pickAvatar,
              child: Column(children: [
                _newAvatar != null
                    ? CircleAvatar(radius: 40, backgroundImage: FileImage(_newAvatar!))
                    : AvatarWidget(url: widget.userData['avatarUrl'], name: widget.userData['fullName'] ?? '', size: 80),
                const SizedBox(height: 8),
                const Text('Change photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0095F6))),
              ]),
            ),
            const SizedBox(height: 24),
            _field(_nameCtrl, 'Name'),
            _field(_usernameCtrl, 'Username'),
            _field(_bioCtrl, 'Bio'),
          ]),
        )),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 16, color: Color(0xFF262626)),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDBDBDB))),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDBDBDB))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF262626))),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
        ),
      ]),
    );
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
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
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
    final canSave = _curCtrl.text.isNotEmpty && _newCtrl.text.length >= 6 && _newCtrl.text == _confCtrl.text;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDBDBDB), width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 24)),
            const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: canSave && !_saving ? _change : null,
              child: Icon(Icons.check, color: canSave ? const Color(0xFF0095F6) : const Color(0xFFDBDBDB), size: 24),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _passField(_curCtrl, 'Current Password'),
          _passField(_newCtrl, 'New Password'),
          _passField(_confCtrl, 'Confirm New Password'),
        ])),
      ]),
    );
  }

  Widget _passField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        TextField(
          controller: ctrl, obscureText: true,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDBDBDB))),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDBDBDB))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF262626))),
            contentPadding: EdgeInsets.symmetric(vertical: 8), isDense: true,
          ),
        ),
      ]),
    );
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
    final isVerified = widget.userData['isVerified'] == true;
    final isPending = widget.userData['verificationStatus'] == 'pending';

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDBDBDB), width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 24)),
            const Text('Request Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (!isVerified && !isPending)
              GestureDetector(
                onTap: _linkCtrl.text.isNotEmpty && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2))
                    : Icon(Icons.check, color: _linkCtrl.text.isNotEmpty ? const Color(0xFF0095F6) : const Color(0xFFDBDBDB), size: 24),
              )
            else const SizedBox(width: 24),
          ]),
        ),
        Expanded(child: isVerified
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.verified, color: Color(0xFF0095F6), size: 64),
              const SizedBox(height: 12),
              const Text('You are verified', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Your account has a verified badge.', style: TextStyle(color: Color(0xFF8E8E8E))),
            ]))
          : isPending
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.shield, color: Color(0xFF8E8E8E), size: 64),
              const SizedBox(height: 12),
              const Text('Request Pending', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('We are reviewing your request.', style: TextStyle(color: Color(0xFF8E8E8E))),
            ]))
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('A verified badge confirms your account is the authentic presence of a notable public figure.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
              const SizedBox(height: 20),
              const Text('Step 1: Confirm authenticity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Google Drive PDF Link', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              TextField(
                controller: _linkCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'https://drive.google.com/file/d/...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Step 2: Select category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
            ])),
        ),
      ]),
    );
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('verificationRequests').add({
        'userId': uid,
        'username': widget.userData['username'],
        'fullName': widget.userData['fullName'],
        'avatarUrl': widget.userData['avatarUrl'],
        'link': _linkCtrl.text.trim(),
        'category': _category,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
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
      setState(() {
        final usedMB = total / (1024 * 1024);
        _storage = {'used': usedMB, 'free': 1024 - usedMB, 'total': 1024};
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDBDBDB), width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 24)),
            const Text('Admin Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 24),
          ]),
        ),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.storage, size: 20), const SizedBox(width: 8),
            const Text('Storage Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Used: ${_storage['used']!.toStringAsFixed(2)} MB', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('Free: ${_storage['free']!.toStringAsFixed(0)} MB', style: const TextStyle(color: Color(0xFF8E8E8E))),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_storage['used']! / _storage['total']!).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFDBDBDB),
                color: const Color(0xFF0095F6),
                minHeight: 8,
              ),
            ),
          ])),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFDBDBDB)),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.delete, size: 20, color: Color(0xFFED4956)), const SizedBox(width: 8),
            const Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFED4956)))]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Clear All Chats', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFED4956))),
              const SizedBox(height: 4),
              const Text('Permanently delete all chats and messages for all users.', style: TextStyle(fontSize: 12, color: Color(0xFFED4956))),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _deleteText = v),
                decoration: InputDecoration(
                  hintText: 'Type "sudo delete chat-all"',
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.red.shade200)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _deleteText == 'sudo delete chat-all' && !_deleting ? _deleteAll : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED4956), disabledBackgroundColor: Colors.red.shade200),
                child: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete All Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
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

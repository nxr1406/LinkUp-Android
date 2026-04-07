import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel me;
  const EditProfileScreen({super.key, required this.me});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  bool _loading = false;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(text: widget.me.displayName);
    _usernameCtrl = TextEditingController(text: widget.me.username);
    _bioCtrl = TextEditingController(text: widget.me.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_displayNameCtrl.text.trim().isEmpty ||
        _usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fields cannot be empty')));
      return;
    }
    setState(() => _loading = true);
    try {
      await _userService.updateProfile(
        uid: widget.me.uid,
        displayName: _displayNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildField(
                controller: _displayNameCtrl,
                label: 'Display Name',
                icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildField(
                controller: _usernameCtrl,
                label: 'Username',
                icon: Icons.alternate_email),
            const SizedBox(height: 8),
            const Text(
              'Username can only contain letters, numbers, and underscores.',
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildField(
                controller: _bioCtrl,
                label: 'Bio',
                icon: Icons.notes_outlined,
                maxLines: 3),
            const SizedBox(height: 8),
            const Text(
              'Write a short bio about yourself.',
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.grey),
          prefixIcon: Icon(icon, color: AppColors.grey, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

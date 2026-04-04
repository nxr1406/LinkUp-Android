import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../services/catbox_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _purple = Color(0xFF5865F2);
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  File? _avatar;
  bool _loading = false;
  String _usernameError = '';
  bool _usernameOk = false;

  bool get _isValid => _nameCtrl.text.isNotEmpty && _usernameOk && _emailCtrl.text.contains('@') && _passCtrl.text.length >= 6;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_checkUsername);
  }

  Future<void> _checkUsername() async {
    final u = _usernameCtrl.text.trim();
    if (u.length < 3) { setState(() { _usernameError = ''; _usernameOk = false; }); return; }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(u)) {
      setState(() { _usernameError = 'Only lowercase, numbers, underscores'; _usernameOk = false; }); return;
    }
    try {
      final q = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: u).get();
      setState(() { _usernameError = q.docs.isNotEmpty ? 'Username taken' : ''; _usernameOk = q.docs.isEmpty; });
    } catch (_) { setState(() { _usernameError = ''; _usernameOk = true; }); }
  }

  Future<void> _pickAvatar() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null) setState(() => _avatar = File(p.path));
  }

  Future<void> _register() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text);
      String avatarUrl = '';
      if (_avatar != null) avatarUrl = await CatboxService.uploadFile(_avatar!) ?? '';
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'fullName': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'avatarUrl': avatarUrl,
        'bio': '', 'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false, 'verificationStatus': 'none',
        'role': 'user', 'followers': [], 'following': [],
      });
      if (mounted) context.go('/app');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Registration failed'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 32),
            const Text('Create an account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 6),
            const Text('Join LinkUp today', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 28),

            // Card
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Avatar picker
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(children: [
                    _avatar != null
                        ? CircleAvatar(radius: 44, backgroundImage: FileImage(_avatar!))
                        : Container(width: 88, height: 88,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE0E0F0), width: 2, style: BorderStyle.solid)),
                            child: const Icon(Icons.person_outline, size: 44, color: Color(0xFFB0B0D0))),
                    Positioned(bottom: 0, right: 0,
                      child: Container(width: 28, height: 28,
                        decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white))),
                  ]),
                ),
                const SizedBox(height: 20),

                // Fields
                _field(_nameCtrl, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _field(_usernameCtrl, 'Username', Icons.alternate_email),
                  if (_usernameError.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(_usernameError, style: const TextStyle(fontSize: 11, color: Colors.red))),
                ]),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Email address', Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_passCtrl, 'Password', Icons.lock_outline, obscure: true),
                const SizedBox(height: 20),

                SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isValid && !_loading ? _register : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      disabledBackgroundColor: _purple.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account? ', style: TextStyle(fontSize: 14, color: Colors.grey)),
              GestureDetector(onTap: () => context.go('/login'),
                child: const Text('Sign in', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _purple))),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, TextInputType? type}) {
    return TextField(
      controller: ctrl, obscureText: obscure, keyboardType: type,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true, fillColor: const Color(0xFFF5F6FF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8FF))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8FF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple, width: 1.5)),
      ),
    );
  }

  @override
  void dispose() { _nameCtrl.dispose(); _usernameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }
}

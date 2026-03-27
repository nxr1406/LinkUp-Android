import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/catbox_service.dart';
import '../utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  bool _uploadingAvatar = false;

  String _usernameError = '';
  bool _isUsernameValid = false;

  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_checkUsername);
  }

  void _checkUsername() async {
    final username = _usernameCtrl.text;
    if (username.length < 3) {
      setState(() {
        _usernameError = '';
        _isUsernameValid = false;
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameError = 'Lowercase letters, numbers, underscores only';
        _isUsernameValid = false;
      });
      return;
    }
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      if (!mounted) return;
      if (q.docs.isNotEmpty) {
        setState(() {
          _usernameError = 'Username taken';
          _isUsernameValid = false;
        });
      } else {
        setState(() {
          _usernameError = '';
          _isUsernameValid = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isUsernameValid = true);
    }
  }

  bool get _isEmailValid =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailCtrl.text);
  bool get _isPasswordValid => _passwordCtrl.text.length >= 8;
  bool get _isConfirmValid =>
      _passwordCtrl.text == _confirmCtrl.text &&
      _passwordCtrl.text.isNotEmpty;
  bool get _isFullNameValid => _fullNameCtrl.text.length >= 2;

  bool get _isValid =>
      _isFullNameValid &&
      _isUsernameValid &&
      _isEmailValid &&
      _isPasswordValid &&
      _isConfirmValid;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _handleRegister() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);

    try {
      String avatarUrl = '';
      if (_avatarFile != null) {
        setState(() => _uploadingAvatar = true);
        final url = await CatboxService.uploadImage(_avatarFile!);
        setState(() => _uploadingAvatar = false);
        if (url == null) {
          _showError('Avatar upload failed. Please try again.');
          setState(() => _loading = false);
          return;
        }
        avatarUrl = url;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'fullName': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'email': _emailCtrl.text.trim(),
        'avatarUrl': avatarUrl,
        'bio': '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'blockedUsers': [],
        'notificationsEnabled': true,
      });

      if (mounted) context.go('/app');
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'Registration failed. Try again.';
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _validIcon(bool valid) {
    return Icon(
      valid ? Icons.check_circle : Icons.cancel,
      color: valid ? AppColors.success : AppColors.error,
      size: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Logo
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.instagramGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 24),
                    // Avatar picker
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
                                ? const Icon(Icons.person,
                                    color: Colors.white, size: 40)
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
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_uploadingAvatar)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.border,
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Full name
                    TextField(
                      controller: _fullNameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Full Name',
                        suffixIcon: _fullNameCtrl.text.isNotEmpty
                            ? _validIcon(_isFullNameValid)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Username
                    TextField(
                      controller: _usernameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Username',
                        suffixIcon: _usernameCtrl.text.isNotEmpty
                            ? _validIcon(_isUsernameValid)
                            : null,
                        errorText: _usernameError.isNotEmpty
                            ? _usernameError
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Email
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        suffixIcon: _emailCtrl.text.isNotEmpty
                            ? _validIcon(_isEmailValid)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Password
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.subText,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Confirm password
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: !_showPassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Confirm Password',
                        suffixIcon: _confirmCtrl.text.isNotEmpty
                            ? _validIcon(_isConfirmValid)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isValid && !_loading ? _handleRegister : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isValid
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.5),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Sign up'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const Divider(height: 0, color: AppColors.border, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: GestureDetector(
                onTap: () => context.go('/login'),
                child: RichText(
                  text: const TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(color: AppColors.subText, fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Log in',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}

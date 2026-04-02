import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

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
  final _confirmPasswordCtrl = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;

  String _usernameError = '';
  bool _isUsernameValid = false;
  String _emailError = '';
  bool _isEmailAvailable = false;

  File? _avatarFile;

  bool get _isValid =>
      _fullNameCtrl.text.isNotEmpty &&
      _isUsernameValid &&
      _isEmailAvailable &&
      _passwordCtrl.text.length >= 6 &&
      _passwordCtrl.text == _confirmPasswordCtrl.text;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_checkUsername);
    _emailCtrl.addListener(_checkEmail);
  }

  Future<void> _checkUsername() async {
    final username = _usernameCtrl.text.trim();
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
      setState(() {
        if (q.docs.isNotEmpty) {
          _usernameError = 'Username taken';
          _isUsernameValid = false;
        } else {
          _usernameError = '';
          _isUsernameValid = true;
        }
      });
    } catch (_) {
      setState(() {
        _usernameError = '';
        _isUsernameValid = true;
      });
    }
  }

  Future<void> _checkEmail() async {
    final email = _emailCtrl.text.trim();
    final isValidFormat =
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!isValidFormat) {
      setState(() {
        _emailError = '';
        _isEmailAvailable = false;
      });
      return;
    }
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      setState(() {
        if (q.docs.isNotEmpty) {
          _emailError = 'Email already registered';
          _isEmailAvailable = false;
        } else {
          _emailError = '';
          _isEmailAvailable = true;
        }
      });
    } catch (_) {
      setState(() {
        _emailError = '';
        _isEmailAvailable = true;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<String?> _uploadToCatbox(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.bytesToString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      String avatarUrl = '';
      if (_avatarFile != null) {
        avatarUrl = await _uploadToCatbox(_avatarFile!) ?? '';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'fullName': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'avatarUrl': avatarUrl,
        'bio': '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
        'verificationStatus': 'none',
        'role': 'user',
      });

      if (mounted) context.go('/app');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Registration failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDBDBDB)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LinkUp',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF262626),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Avatar picker
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFDBDBDB),
                              backgroundImage: _avatarFile != null
                                  ? FileImage(_avatarFile!)
                                  : null,
                              child: _avatarFile == null
                                  ? const Icon(Icons.person,
                                      size: 40, color: Colors.white)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0095F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildField(_fullNameCtrl, 'Full Name'),
                      const SizedBox(height: 8),
                      _buildFieldWithStatus(
                        _usernameCtrl,
                        'Username',
                        error: _usernameError,
                        isValid: _isUsernameValid,
                      ),
                      const SizedBox(height: 8),
                      _buildFieldWithStatus(
                        _emailCtrl,
                        'Email',
                        keyboardType: TextInputType.emailAddress,
                        error: _emailError,
                        isValid: _isEmailAvailable,
                      ),
                      const SizedBox(height: 8),
                      _buildField(_passwordCtrl, 'Password',
                          obscure: !_showPassword),
                      const SizedBox(height: 8),
                      _buildField(
                          _confirmPasswordCtrl, 'Confirm Password',
                          obscure: true),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed:
                              _isValid && !_loading ? _handleRegister : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0095F6),
                            disabledBackgroundColor:
                                const Color(0xFF0095F6).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Sign up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDBDBDB)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Have an account? ',
                          style: TextStyle(fontSize: 14)),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0095F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 12),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _buildFieldWithStatus(
    TextEditingController ctrl,
    String hint, {
    String error = '',
    bool isValid = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12),
          decoration: _inputDecoration(hint).copyWith(
            suffixIcon: ctrl.text.length >= 3
                ? Icon(
                    isValid ? Icons.check_circle : Icons.cancel,
                    color: isValid ? Colors.green : Colors.red,
                    size: 18,
                  )
                : null,
          ),
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(error,
                style: const TextStyle(fontSize: 11, color: Colors.red)),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFA8A8A8)),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }
}

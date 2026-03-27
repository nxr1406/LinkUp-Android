import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;

  bool get _isValid =>
      _identifierCtrl.text.isNotEmpty && _passwordCtrl.text.length >= 8;

  Future<void> _handleLogin() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);
    try {
      String email = _identifierCtrl.text.trim();
      if (!email.contains('@')) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: email.toLowerCase())
            .get();
        if (q.docs.isEmpty) throw Exception('User not found');
        email = q.docs.first.data()['email'] ?? '';
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: _passwordCtrl.text);
      if (mounted) context.go('/app');
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      _showError('Please enter your email or username first');
      return;
    }
    try {
      String email = identifier;
      if (!email.contains('@')) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: email.toLowerCase())
            .get();
        if (q.docs.isEmpty) throw Exception('User not found');
        email = q.docs.first.data()['email'] ?? '';
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _showSuccess('We sent a reset link to your email');
    } catch (e) {
      _showError(e.toString());
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email/username.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email.';
      default:
        return 'Login failed. Please try again.';
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

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
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
                    const SizedBox(height: 60),
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
                    const SizedBox(height: 32),
                    // Fields
                    TextField(
                      controller: _identifierCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          hintText: 'Email or Username'),
                    ),
                    const SizedBox(height: 10),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        child: const Text('Forgot password?',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isValid && !_loading ? _handleLogin : null,
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
                          : const Text('Log in'),
                    ),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(
                          child: Divider(color: AppColors.border, thickness: 0.5)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                color: AppColors.subText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Expanded(
                          child: Divider(color: AppColors.border, thickness: 0.5)),
                    ]),
                  ],
                ),
              ),
            ),
            const Divider(height: 0, color: AppColors.border, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: GestureDetector(
                onTap: () => context.go('/register'),
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(color: AppColors.subText, fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Sign up',
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
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

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

  static const _purple = Color(0xFF5865F2);

  bool get _isValid => _identifierCtrl.text.isNotEmpty && _passwordCtrl.text.length >= 6;

  Future<void> _login() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);
    try {
      String email = _identifierCtrl.text.trim();
      if (!email.contains('@')) {
        final q = await FirebaseFirestore.instance.collection('users')
            .where('username', isEqualTo: email.toLowerCase()).get();
        if (q.docs.isEmpty) { _snack('No account found.'); return; }
        email = q.docs.first.data()['email'];
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: _passwordCtrl.text);
      if (mounted) context.go('/app');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') _snack('No account found with this email/username.');
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential') _snack('Incorrect password.');
      else _snack('Login failed. Please try again.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _resetPassword() async {
    final id = _identifierCtrl.text.trim();
    if (id.isEmpty) { _snack('Enter your email or username first'); return; }
    try {
      String email = id;
      if (!id.contains('@')) {
        final q = await FirebaseFirestore.instance.collection('users')
            .where('username', isEqualTo: id.toLowerCase()).get();
        if (q.docs.isEmpty) { _snack('No account found.'); return; }
        email = q.docs.first.data()['email'];
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Reset link sent!', success: true);
    } catch (_) { _snack('Failed to send reset email.'); }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 40),
              const Text('Welcome Back!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _purple)),
              const SizedBox(height: 8),
              const Text('Sign in to continue to LinkUp', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 40),

              // Email field
              _InputField(
                controller: _identifierCtrl,
                hint: 'Email Address',
                icon: Icons.email_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Password field
              _InputField(
                controller: _passwordCtrl,
                hint: 'Password',
                icon: Icons.lock_outline,
                obscure: !_showPassword,
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey, size: 20),
                ),
              ),
              const SizedBox(height: 8),

              // Forgot password
              Align(alignment: Alignment.centerRight,
                child: TextButton(onPressed: _resetPassword,
                  child: const Text('Forgot Password?', style: TextStyle(color: _purple, fontWeight: FontWeight.w600, fontSize: 13)))),
              const SizedBox(height: 16),

              // Sign in button
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isValid && !_loading ? _login : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    disabledBackgroundColor: _purple.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),

              // OR divider
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12))),
                const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
              ]),
              const SizedBox(height: 24),

              // Don't have account
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account? ", style: TextStyle(fontSize: 14, color: Colors.grey)),
                GestureDetector(onTap: () => context.go('/register'),
                  child: const Text('Sign Up', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _purple))),
              ]),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _identifierCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final void Function(String)? onChanged;
  final Widget? suffix;

  const _InputField({required this.controller, required this.hint, required this.icon,
    this.obscure = false, this.onChanged, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, obscureText: obscure, onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: const Color(0xFFF5F6FF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8FF))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8E8FF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF5865F2), width: 1.5)),
      ),
    );
  }
}

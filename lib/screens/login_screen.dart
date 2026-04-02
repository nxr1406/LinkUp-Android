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

  bool get _isValid =>
      _identifierCtrl.text.isNotEmpty && _passwordCtrl.text.length >= 6;

  Future<void> _handleLogin() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);

    try {
      String email = _identifierCtrl.text.trim();

      // If not email, look up by username
      if (!email.contains('@')) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: email.toLowerCase())
            .get();
        if (q.docs.isEmpty) {
          _showSnack('No account found with this username.');
          return;
        }
        email = q.docs.first.data()['email'];
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordCtrl.text,
      );

      if (mounted) context.go('/app');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showSnack('No account found with this email/username.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showSnack('Incorrect password or email.');
      } else {
        _showSnack('Login failed. Please check your credentials.');
      }
    } catch (_) {
      _showSnack('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      _showSnack('Please enter your email or username first');
      return;
    }

    try {
      String email = identifier;
      if (!identifier.contains('@')) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: identifier.toLowerCase())
            .get();
        if (q.docs.isEmpty) {
          _showSnack('No account found.');
          return;
        }
        email = q.docs.first.data()['email'];
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Reset link sent to your email', isSuccess: true);
    } catch (_) {
      _showSnack('Failed to send reset email.');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 32),
                  child: CustomPaint(painter: _LogoPainter()),
                ),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDBDBDB)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    children: [
                      // Identifier field
                      _buildTextField(
                        controller: _identifierCtrl,
                        hint: 'Email or Username',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),

                      // Password field
                      _buildPasswordField(),
                      const SizedBox(height: 8),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleResetPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00376B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isValid && !_loading ? _handleLogin : null,
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
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),

                      // Divider
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Color(0xFFDBDBDB))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF737373),
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Color(0xFFDBDBDB))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Sign up card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDBDBDB)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF262626)),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/register'),
                        child: const Text(
                          'Sign up',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
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
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: !_showPassword,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Password',
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
        suffixIcon: IconButton(
          onPressed: () => setState(() => _showPassword = !_showPassword),
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: const Color(0xFF8E8E8E),
          ),
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

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFFFCAF45),
          Color(0xFFF77737),
          Color(0xFFF56040),
          Color(0xFFC13584),
          Color(0xFF833AB4),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.4;

    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;
  bool _loading = false;
  bool _obscure = true;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.signIn(email: email, password: password);
      // AuthWrapper handles navigation automatically via authStateChanges stream
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('user-not-found') ||
          msg.contains('wrong-password') ||
          msg.contains('invalid-credential') ||
          msg.contains('INVALID_LOGIN_CREDENTIALS') ||
          msg.contains('invalid-email')) {
        msg = 'Invalid email or password';
      } else if (msg.contains('network-request-failed')) {
        msg = 'No internet connection';
      } else if (msg.contains('too-many-requests')) {
        msg = 'Too many attempts. Try again later';
      } else if (msg.contains('SUSPENDED') || msg.contains('suspended')) {
        msg = 'Your account has been suspended';
      } else {
        msg = 'Sign in failed. Check your credentials';
      }
      if (mounted) _showError(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Enter your email first');
      return;
    }
    try {
      await _authService.sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password reset email sent!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      _showError('Could not send reset email. Check the address.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              // ── TOP-RIGHT blobs (fixed, not scrolling) ──
              Positioned(top: -55, right: -35,
                  child: _PinkBlob(size: w * 0.56)),
              Positioned(top: h * 0.06, right: w * 0.18,
                  child: _PinkBlob(size: w * 0.35, opacity: 0.65)),

              // ── BOTTOM blobs (fixed) ──
              Positioned(bottom: -45, left: -45,
                  child: _PinkBlob(size: w * 0.58)),
              Positioned(bottom: h * 0.05, right: -25,
                  child: _PinkBlob(size: w * 0.38, opacity: 0.70)),

              // ── SCROLLABLE CONTENT ──
              SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: h),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: h * 0.07),

                          const Text('Welcome\nBack',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                                height: 1.2,
                              )),
                          const SizedBox(height: 8),
                          const Text('Hey! Good to see you again',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textMedium)),
                          const SizedBox(height: 40),

                          _buildField(
                            controller: _emailCtrl,
                            hint: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _passwordCtrl,
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            obscure: _obscure,
                            toggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                SizedBox(
                                  width: 36, height: 36,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) =>
                                        setState(() => _rememberMe = v ?? false),
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const Text('Remember me',
                                    style: TextStyle(
                                        color: AppColors.textMedium,
                                        fontSize: 13)),
                              ]),
                              TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Forgot password?',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withOpacity(0.7),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32)),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5))
                                  : const Text('SIGN IN',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.4)),
                            ),
                          ),
                          const SizedBox(height: 22),

                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pushReplacement(context,
                                  MaterialPageRoute(
                                      builder: (_) => const SignUpScreen())),
                              child: RichText(
                                text: const TextSpan(
                                  text: "Don't have an account? ",
                                  style: TextStyle(
                                      color: AppColors.textMedium, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: 'Sign up',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: h * 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.grey),
          prefixIcon: Icon(icon, color: AppColors.grey, size: 20),
          suffixIcon: toggleObscure != null
              ? IconButton(
                  icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.grey, size: 20),
                  onPressed: toggleObscure)
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _PinkBlob extends StatelessWidget {
  final double size;
  final double opacity;
  const _PinkBlob({required this.size, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.62),
            topRight: Radius.circular(size * 0.28),
            bottomLeft: Radius.circular(size * 0.38),
            bottomRight: Radius.circular(size * 0.62),
          ),
        ),
      ),
    );
  }
}

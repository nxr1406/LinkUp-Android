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
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;
  bool _loading    = false;
  bool _obscure    = true;
  final _authService = AuthService();

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) { _showError('Please fill in all fields'); return; }
    setState(() => _loading = true);
    try {
      await _authService.signIn(email: email, password: password);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('user-not-found') || msg.contains('wrong-password') ||
          msg.contains('invalid-credential') || msg.contains('INVALID_LOGIN_CREDENTIALS') ||
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
    if (_emailCtrl.text.trim().isEmpty) { _showError('Enter your email first'); return; }
    try {
      await _authService.sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset email sent!'), backgroundColor: Colors.green));
    } catch (_) { _showError('Could not send reset email. Check the address.'); }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    const dark = false;
    const textColor   = AppColors.black;
    const subColor    = AppColors.textMedium;
    const bgColor     = AppColors.background;
    const overlayStyle = SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(children: [
            // blobs (lighter in dark mode)
            Positioned(top: -55, right: -35,
                child: _PinkBlob(size: w * 0.56, dark: dark)),
            Positioned(top: h * 0.06, right: w * 0.18,
                child: _PinkBlob(size: w * 0.35, opacity: 0.55, dark: dark)),
            Positioned(bottom: -45, left: -45,
                child: _PinkBlob(size: w * 0.58, dark: dark)),
            Positioned(bottom: h * 0.05, right: -25,
                child: _PinkBlob(size: w * 0.38, opacity: 0.60, dark: dark)),

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
                        Text('Welcome\nBack',
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                                color: textColor, height: 1.2)),
                        const SizedBox(height: 8),
                        Text('Hey! Good to see you again',
                            style: TextStyle(fontSize: 15, color: subColor)),
                        const SizedBox(height: 40),

                        _buildField(dark: dark, controller: _emailCtrl, hint: 'Email',
                            icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildField(dark: dark, controller: _passwordCtrl, hint: 'Password',
                            icon: Icons.lock_rounded_rounded, obscure: _obscure,
                            toggleObscure: () => setState(() => _obscure = !_obscure)),
                        const SizedBox(height: 6),

                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            SizedBox(width: 36, height: 36,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                activeColor: AppColors.primary,
                                checkColor: Colors.white,
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            Text('Remember me', style: TextStyle(color: subColor, fontSize: 13)),
                          ]),
                          TextButton(
                            onPressed: _forgotPassword,
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero, minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Forgot password?',
                                style: TextStyle(color: AppColors.primary, fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ]),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.primary.withOpacity(0.7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('SIGN IN',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.4)),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacement(context,
                                MaterialPageRoute(builder: (_) => const SignUpScreen())),
                            child: RichText(
                              text: TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(color: subColor, fontSize: 14),
                                children: const [TextSpan(text: 'Sign up',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))],
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
          ]);
        }),
      ),
    );
  }

  Widget _buildField({
    required bool dark,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    const fieldBg   = AppColors.white;
    const textColor = AppColors.textDark;
    const hintColor = AppColors.grey;

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(icon, color: hintColor, size: 20),
          suffixIcon: toggleObscure != null
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: hintColor, size: 20),
                  onPressed: toggleObscure)
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _PinkBlob extends StatelessWidget {
  final double size, opacity;
  final bool dark;
  const _PinkBlob({required this.size, this.opacity = 1.0, required this.dark});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size, height: size,
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

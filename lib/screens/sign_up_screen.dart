import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl       = TextEditingController();
  final _usernameCtrl    = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  bool _agreePolicy    = false;
  bool _loading        = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose(); _usernameCtrl.dispose(); _displayNameCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose(); super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_agreePolicy) { _showError('Please agree to the privacy policy'); return; }
    if (_emailCtrl.text.trim().isEmpty || _usernameCtrl.text.trim().isEmpty ||
        _displayNameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      _showError('Please fill in all fields'); return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) { _showError('Passwords do not match'); return; }
    if (_passwordCtrl.text.length < 6) { _showError('Password must be at least 6 characters'); return; }
    if (_usernameCtrl.text.trim().length < 3) { _showError('Username must be at least 3 characters'); return; }
    setState(() => _loading = true);
    try {
      await _authService.signUp(
        email: _emailCtrl.text.trim(), password: _passwordCtrl.text,
        username: _usernameCtrl.text.trim(), displayName: _displayNameCtrl.text.trim());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('email-already-in-use')) msg = 'Email already in use';
      else if (msg.contains('Username already taken')) msg = 'Username already taken';
      else if (msg.contains('network-request-failed')) msg = 'No internet connection';
      else if (msg.contains('invalid-email')) msg = 'Invalid email address';
      else if (msg.contains('weak-password')) msg = 'Password is too weak';
      else if (msg.contains('too-many-requests')) msg = 'Too many attempts. Try again later';
      if (mounted) _showError(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    final dark      = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? AppColors.darkText       : AppColors.black;
    final subColor  = dark ? AppColors.darkTextMedium : AppColors.textMedium;
    final bgColor   = dark ? AppColors.darkBackground : AppColors.background;
    final overlayStyle = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(children: [
            Positioned(top: -60, right: -40,
                child: _PinkBlob(size: w * 0.60, dark: dark)),
            Positioned(top: h * 0.05, right: w * 0.20,
                child: _PinkBlob(size: w * 0.38, opacity: 0.65, dark: dark)),
            Positioned(bottom: -45, left: -45,
                child: _PinkBlob(size: w * 0.56, dark: dark)),
            Positioned(bottom: h * 0.04, right: -22,
                child: _PinkBlob(size: w * 0.36, opacity: 0.68, dark: dark)),

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
                        SizedBox(height: h * 0.06),
                        Text('Sign Up',
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 6),
                        Text("Hello! let's join with us",
                            style: TextStyle(fontSize: 15, color: subColor)),
                        const SizedBox(height: 32),

                        _buildField(dark: dark, controller: _emailCtrl, hint: 'Email',
                            icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildField(dark: dark, controller: _usernameCtrl,
                            hint: 'Username', icon: Icons.alternate_email),
                        const SizedBox(height: 14),
                        _buildField(dark: dark, controller: _displayNameCtrl,
                            hint: 'Display Name', icon: Icons.person_outline),
                        const SizedBox(height: 14),
                        _buildField(dark: dark, controller: _passwordCtrl,
                            hint: 'Password', icon: Icons.lock_outline,
                            obscure: _obscurePass,
                            toggleObscure: () => setState(() => _obscurePass = !_obscurePass)),
                        const SizedBox(height: 14),
                        _buildField(dark: dark, controller: _confirmCtrl,
                            hint: 'Confirm Password', icon: Icons.lock_outline,
                            obscure: _obscureConfirm,
                            toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                        const SizedBox(height: 12),

                        Row(children: [
                          SizedBox(width: 36, height: 36,
                            child: Checkbox(
                              value: _agreePolicy,
                              onChanged: (v) => setState(() => _agreePolicy = v ?? false),
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              side: BorderSide(color: dark ? Colors.white30 : Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('I agree with privacy policy',
                              style: TextStyle(color: subColor, fontSize: 14)),
                        ]),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.primary.withOpacity(0.7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('SIGN UP',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.4)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacement(context,
                                MaterialPageRoute(builder: (_) => const SignInScreen())),
                            child: RichText(
                              text: TextSpan(
                                text: 'You already have an account? ',
                                style: TextStyle(color: subColor, fontSize: 14),
                                children: const [TextSpan(text: 'Sign in',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.16),
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
    final fieldBg   = dark ? AppColors.darkCard       : AppColors.white;
    final textColor = dark ? AppColors.darkText       : AppColors.textDark;
    final hintColor = dark ? AppColors.darkTextMedium : AppColors.grey;
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.3 : 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controller, obscureText: obscure, keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(icon, color: hintColor, size: 20),
          suffixIcon: toggleObscure != null
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                      color: hintColor, size: 20),
                  onPressed: toggleObscure)
              : null,
          border: InputBorder.none, enabledBorder: InputBorder.none,
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
      opacity: dark ? opacity * 0.18 : opacity,
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

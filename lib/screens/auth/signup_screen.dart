import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:linkup_chat_app/providers/auth_provider.dart';
import 'package:linkup_chat_app/screens/home/home_screen.dart';
import 'package:linkup_chat_app/widgets/custom_button.dart';
import 'package:linkup_chat_app/widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      username: _usernameController.text.trim(),
      bio: _bioController.text.trim(),
    );
    if (auth.currentUser != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            CustomTextField(controller: _usernameController, label: 'Username'),
            const SizedBox(height: 16),
            CustomTextField(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(controller: _bioController, label: 'Bio (optional)'),
            const SizedBox(height: 24),
            CustomButton(text: 'Sign Up', isLoading: auth.isLoading, onPressed: _handleSignup),
          ],
        ),
      ),
    );
  }
}

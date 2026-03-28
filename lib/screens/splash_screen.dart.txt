import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:linkup_chat_app/providers/auth_provider.dart';
import 'package:linkup_chat_app/auth/login_screen.dart';
import 'package:linkup_chat_app/screens/home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => auth.user != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_rounded, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'LinkUp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

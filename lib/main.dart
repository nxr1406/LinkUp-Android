import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/get_started_screen.dart';
import 'screens/home_screen.dart';
import 'screens/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LinkUpApp());
}

class LinkUpApp extends StatefulWidget {
  const LinkUpApp({super.key});

  static _LinkUpAppState? _instance;
  static void toggleTheme() => _instance?.toggleTheme();
  static bool get isDark => _instance?._themeProvider.isDark ?? false;

  @override
  State<LinkUpApp> createState() => _LinkUpAppState();
}

class _LinkUpAppState extends State<LinkUpApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    LinkUpApp._instance = this;
    _themeProvider.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});
  void toggleTheme() => _themeProvider.toggle();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: _themeProvider.themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Authenticated → Home (wrapped with App Lock)
        if (snapshot.hasData && snapshot.data != null) {
          // Reset status bar to light for home screen
          SystemChrome.setSystemUIOverlayStyle(
            LinkUpApp.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
          );
          return const AppLockWrapper(child: HomeScreen());
        }

        // Not authenticated → Get Started
        return const GetStartedScreen();
      },
    );
  }
}

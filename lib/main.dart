import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/blocked_users_screen.dart';
import 'screens/main_layout.dart';
import 'screens/suspended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LinkUpAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const LinkUpApp(),
    ),
  );
}

class LinkUpApp extends StatelessWidget {
  const LinkUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<LinkUpAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isLoggedIn = authProvider.currentUser != null;
        final isLoading = authProvider.isLoading;
        final isSuspended = authProvider.userData?['isSuspended'] == true;
        if (isLoading) return null;
        final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/app';
        if (isLoggedIn && isSuspended && state.matchedLocation != '/suspended') return '/suspended';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/suspended', builder: (_, __) => const SuspendedScreen()),
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(path: '/app', builder: (_, __) => const HomeScreen()),
            GoRoute(path: '/app/search', builder: (_, __) => const SearchScreen()),
            GoRoute(path: '/app/profile', builder: (_, __) => const ProfileScreen()),
            GoRoute(path: '/app/notifications', builder: (_, __) => const NotificationsScreen()),
            GoRoute(path: '/app/privacy', builder: (_, __) => const PrivacyScreen()),
            GoRoute(path: '/app/blocked', builder: (_, __) => const BlockedUsersScreen()),
            GoRoute(path: '/app/user/:userId', builder: (_, state) => UserProfileScreen(userId: state.pathParameters['userId']!)),
          ],
        ),
        GoRoute(path: '/chat/:chatId', builder: (_, state) => ChatScreen(chatId: state.pathParameters['chatId']!)),
      ],
    );

    return MaterialApp.router(
      title: 'LinkUp',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(primary: Color(0xFF5865F2), surface: Colors.white),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0, foregroundColor: Color(0xFF262626)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: Color(0xFF5865F2), surface: Color(0xFF1A1A2E)),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F0F1A), elevation: 0, foregroundColor: Colors.white),
      ),
      routerConfig: router,
    );
  }
}

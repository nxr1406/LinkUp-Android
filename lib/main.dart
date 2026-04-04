import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Background handler আগে register করো — Firebase init এর আগে
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Notification service initialize
  await NotificationService.initialize();

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
        useMaterial3: false,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0095F6),
          secondary: Color(0xFF0095F6),
          surface: Colors.white,
          background: Colors.white,
          onSurface: Color(0xFF262626),
          onBackground: Color(0xFF262626),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Color(0xFF262626),
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: const Color(0xFFDBDBDB),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0095F6),
          secondary: Color(0xFF0095F6),
          surface: Color(0xFF1C1C1E),
          background: Color(0xFF000000),
          onSurface: Colors.white,
          onBackground: Colors.white,
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1E),
          elevation: 0,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardColor: const Color(0xFF1C1C1E),
        dividerColor: const Color(0xFF38383A),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1C1C1E),
          selectedItemColor: Color(0xFF0095F6),
          unselectedItemColor: Color(0xFF8E8E93),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Color(0xFF8E8E93)),
          border: InputBorder.none,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white,
          textColor: Colors.white,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith(
              (s) => s.contains(MaterialState.selected)
                  ? const Color(0xFF0095F6)
                  : const Color(0xFF8E8E93)),
          trackColor: MaterialStateProperty.resolveWith(
              (s) => s.contains(MaterialState.selected)
                  ? const Color(0xFF0095F6).withOpacity(0.4)
                  : const Color(0xFF38383A)),
        ),
      ),
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/blocked_users_screen.dart';
import 'screens/main_layout.dart';
import 'screens/suspended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LinkUpApp());
}

class LinkUpApp extends StatelessWidget {
  const LinkUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LinkUpAuthProvider(),
      child: Consumer<LinkUpAuthProvider>(
        builder: (context, authProvider, _) {
          final router = _buildRouter(authProvider);
          return MaterialApp.router(
            title: 'LinkUp',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF0095F6),
                surface: Colors.white,
              ),
              fontFamily: 'SF Pro Display',
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                foregroundColor: Color(0xFF262626),
                titleTextStyle: TextStyle(
                  color: Color(0xFF262626),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }

  GoRouter _buildRouter(LinkUpAuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isLoggedIn = authProvider.currentUser != null;
        final isLoading = authProvider.isLoading;
        final isSuspended = authProvider.userData?['isSuspended'] == true;

        if (isLoading) return null;

        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/app';
        if (isLoggedIn && isSuspended && state.matchedLocation != '/suspended') {
          return '/suspended';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/suspended',
          builder: (context, state) => const SuspendedScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: '/app',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/app/search',
              builder: (context, state) => const SearchScreen(),
            ),
            GoRoute(
              path: '/app/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/app/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/app/blocked',
              builder: (context, state) => const BlockedUsersScreen(),
            ),
            GoRoute(
              path: '/app/user/:userId',
              builder: (context, state) => UserProfileScreen(
                userId: state.pathParameters['userId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/chat/:chatId',
          builder: (context, state) => ChatScreen(
            chatId: state.pathParameters['chatId']!,
          ),
        ),
      ],
    );
  }
}

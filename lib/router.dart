import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as ap;
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/main_layout.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/blocked_users_screen.dart';
import '../screens/privacy_screen.dart';

GoRouter buildRouter(ap.AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/app',
    redirect: (context, state) {
      if (authProvider.loading) return null;
      final loggedIn = authProvider.currentUser != null;
      final onAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/app';
      return null;
    },
    refreshListenable: authProvider,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Chat route (outside the bottom nav shell)
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) =>
            ChatScreen(chatId: state.pathParameters['chatId']!),
      ),

      // User profile outside shell
      GoRoute(
        path: '/app/user/:userId',
        builder: (_, state) =>
            UserProfileScreen(userId: state.pathParameters['userId']!),
      ),

      // Notifications & Blocked & Privacy outside shell
      GoRoute(
          path: '/app/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/app/blocked',
          builder: (_, __) => const BlockedUsersScreen()),
      GoRoute(
          path: '/app/privacy', builder: (_, __) => const PrivacyScreen()),

      // Main shell with bottom nav
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            MainLayout(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/app',
                  builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/app/search',
                  builder: (_, __) => const SearchScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/app/profile',
                  builder: (_, __) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}

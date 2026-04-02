import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/app/search')) return 1;
    if (location.startsWith('/app/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFDBDBDB), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/app');
                break;
              case 1:
                context.go('/app/search');
                break;
              case 2:
                context.go('/app/profile');
                break;
            }
          },
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF262626),
          unselectedItemColor: const Color(0xFF8E8E8E),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                currentIndex == 0
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                size: 26,
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search, size: 26),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                currentIndex == 2 ? Icons.person : Icons.person_outline,
                size: 26,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

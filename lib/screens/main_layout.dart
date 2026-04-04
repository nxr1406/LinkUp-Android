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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final selectedColor = isDark ? Colors.white : const Color(0xFF262626);
    final borderColor = isDark ? const Color(0xFF38383A) : const Color(0xFFDBDBDB);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            switch (index) {
              case 0: context.go('/app'); break;
              case 1: context.go('/app/search'); break;
              case 2: context.go('/app/profile'); break;
            }
          },
          backgroundColor: navBg,
          elevation: 0,
          selectedItemColor: selectedColor,
          unselectedItemColor: const Color(0xFF8E8E8E),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 0 ? Icons.chat_bubble : Icons.chat_bubble_outline, size: 26),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.search, size: 26), label: 'Search'),
            BottomNavigationBarItem(
              icon: Icon(currentIndex == 2 ? Icons.person : Icons.person_outline, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

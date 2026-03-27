import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/theme.dart';

class MainLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          elevation: 0,
          selectedItemColor: AppColors.text,
          unselectedItemColor: AppColors.subText,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 0
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                size: 24,
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 1
                    ? Icons.search
                    : Icons.search_outlined,
                size: 24,
              ),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 2
                    ? Icons.person
                    : Icons.person_outline,
                size: 24,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(onPressed: () => context.go('/app/profile'), icon: const Icon(Icons.arrow_back_ios, size: 20)),
      ),
      body: ListView(children: [
        const _SectionHeader(title: 'Account'),
        _Item(icon: Icons.block, title: 'Blocked Users', onTap: () => context.go('/app/blocked')),
        const Divider(height: 0),
        _Item(icon: Icons.lock_outline, title: 'Change Password', onTap: () {}),
        const Divider(height: 0),
        _Item(icon: Icons.visibility_off_outlined, title: 'Last Seen', onTap: () {}),
        const _SectionHeader(title: 'Data'),
        _Item(icon: Icons.download_outlined, title: 'Download My Data', onTap: () {}),
        const Divider(height: 0),
        _Item(icon: Icons.delete_forever_outlined, title: 'Delete Account', color: Colors.red, onTap: () {}),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E8E))),
  );
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.title, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: color ?? const Color(0xFF262626), size: 22),
    title: Text(title, style: TextStyle(fontSize: 15, color: color ?? const Color(0xFF262626))),
    trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8E8E), size: 20),
  );
}

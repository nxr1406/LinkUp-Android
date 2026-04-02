import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16,16,16,8), child: Text('Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E8E8E)))),
          ListTile(
            leading: const Icon(Icons.block, color: Color(0xFF262626), size: 22),
            title: const Text('Blocked Users', style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8E8E), size: 20),
            onTap: () => context.go('/app/blocked'),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFF262626), size: 22),
            title: const Text('Change Password', style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8E8E), size: 20),
            onTap: () {},
          ),
          const Padding(padding: EdgeInsets.fromLTRB(16,20,16,8), child: Text('Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E8E8E)))),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFED4956), size: 22),
            title: const Text('Delete Account', style: TextStyle(fontSize: 15, color: Color(0xFFED4956))),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

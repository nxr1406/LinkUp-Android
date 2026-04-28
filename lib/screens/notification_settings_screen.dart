import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import 'app_lock_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _messages = true;
  bool _sound = true;
  bool _vibration = true;
  bool _showPreview = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _messages = p.getBool('notif_messages') ?? true;
      _sound = p.getBool('notif_sound') ?? true;
      _vibration = p.getBool('notif_vibration') ?? true;
      _showPreview = p.getBool('notif_preview') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    const dark = false;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(dark),
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg(dark),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary(dark), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications',
            style: TextStyle(
                color: AppColors.textPrimary(dark),
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: 'MESSAGE NOTIFICATIONS', dark: dark),
          _SwitchTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Message Notifications',
            subtitle: 'Get notified when you receive a message',
            value: _messages,
            dark: dark,
            onChanged: (v) {
              setState(() => _messages = v);
              _save('notif_messages', v);
            },
          ),
          _SwitchTile(
            icon: Icons.visibility_outlined,
            title: 'Show Preview',
            subtitle: 'Show message content in notification',
            value: _showPreview,
            dark: dark,
            onChanged: (v) {
              setState(() => _showPreview = v);
              _save('notif_preview', v);
            },
          ),
          _SectionHeader(title: 'ALERT STYLE', dark: dark),
          _SwitchTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Play sound for new messages',
            value: _sound,
            dark: dark,
            onChanged: (v) {
              setState(() => _sound = v);
              _save('notif_sound', v);
            },
          ),
          _SwitchTile(
            icon: Icons.vibration,
            title: 'Vibration',
            subtitle: 'Vibrate for new messages',
            value: _vibration,
            dark: dark,
            onChanged: (v) {
              setState(() => _vibration = v);
              _save('notif_vibration', v);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool dark;
  const _SectionHeader({required this.title, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: AppColors.textSecondary(dark),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value, dark;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon, required this.title, required this.subtitle,
    required this.value, required this.dark, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(dark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary(dark),
                fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: AppColors.textSecondary(dark), fontSize: 12)),
        trailing: LinkUpToggle(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

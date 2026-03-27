import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        size: 20, color: AppColors.text),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Privacy Policy',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Privacy Policy',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    SizedBox(height: 8),
                    Text('LinkUp · NXR Corporation',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.subText)),
                    SizedBox(height: 24),
                    _Section(
                      title: 'What data we collect',
                      body:
                          'We collect your name, username, email address, and optional profile picture. Messages you send are stored temporarily and automatically deleted after 24 hours.',
                    ),
                    _Section(
                      title: 'How we use your data',
                      body:
                          'Your data is used solely to provide the LinkUp messaging service. We do not sell, share, or monetize your personal information.',
                    ),
                    _Section(
                      title: 'Message expiry',
                      body:
                          'All messages are automatically deleted 24 hours after being sent. This cannot be disabled. We do not archive or backup messages.',
                    ),
                    _Section(
                      title: 'Profile pictures',
                      body:
                          'Profile pictures are uploaded to Catbox.moe, a third-party hosting service. By uploading a picture, you agree to their terms of service.',
                    ),
                    _Section(
                      title: 'Account deletion',
                      body:
                          'You can permanently delete your account at any time from the Profile → Settings menu. All associated data will be removed.',
                    ),
                    _Section(
                      title: 'Contact',
                      body:
                          'For privacy concerns, contact us through the NXR Corporation website.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.subText, height: 1.5)),
        ],
      ),
    );
  }
}

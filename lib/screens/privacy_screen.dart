import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/app_colors.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    const dark = false;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(dark),
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg(dark),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.textPrimary(dark), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy & Terms',
          style: TextStyle(
            color: AppColors.textPrimary(dark),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialFile: 'assets/privacy.html',
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
              disableHorizontalScroll: true,
              supportZoom: false,
            ),
            onLoadStop: (controller, url) {
              setState(() => _loading = false);
              // Inject dark mode CSS if needed
              if (dark) {
                controller.evaluateJavascript(source: '''
                  document.body.style.background = '#0F0F14';
                  document.body.style.color = '#F0F0F0';
                  document.querySelectorAll('h2').forEach(e => e.style.color = '#F0F0F0');
                  document.querySelectorAll('p, li').forEach(e => e.style.color = '#AAAAAA');
                ''');
              }
            },
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

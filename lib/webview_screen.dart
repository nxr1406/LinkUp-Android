import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point for the WebView screen
// ─────────────────────────────────────────────────────────────────────────────

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  // ── Controller ──────────────────────────────────────────────────────────────
  late final WebViewController _controller;

  // ── State ────────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;
  double _loadingProgress = 0;

  // ── Connectivity ─────────────────────────────────────────────────────────────
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // ── The local asset entry point ───────────────────────────────────────────────
  // Your Vite build outputs index.html. Since you use HashRouter the fragment
  // (/#/login, /#/app etc.) is handled entirely on the client side — no server
  // route resolution needed. Loading from assets works perfectly.
  static const String _localIndexPath = 'assets/www/index.html';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDownloader();
    _initConnectivity();
    _initWebView();
  }

  // ─── Flutter Downloader ───────────────────────────────────────────────────
  Future<void> _initDownloader() async {
    await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
    FlutterDownloader.registerCallback(_downloadCallback);
  }

  @pragma('vm:entry-point')
  static void _downloadCallback(String id, int status, int progress) {
    // Runs in a background isolate — keep it minimal.
    debugPrint('[Downloader] task=$id status=$status progress=$progress');
  }

  // ─── Connectivity ─────────────────────────────────────────────────────────
  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectivityState(results);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOffline = _isOffline;
      _updateConnectivityState(results);

      // Auto-reload when coming back online only if we were showing error.
      if (wasOffline && !_isOffline && _hasError) {
        _reloadWebView();
      }
    });
  }

  void _updateConnectivityState(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (mounted) setState(() => _isOffline = offline);
  }

  // ─── WebView Initialisation ───────────────────────────────────────────────
  Future<void> _initWebView() async {
    // Request permissions before constructing the controller so that the
    // browser-level file/camera pickers work on first use.
    await _requestPermissions();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)

      // ── Navigation delegate ──────────────────────────────────────────────
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress / 100);
            }
          },
          onPageStarted: (_) {
            if (mounted) setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            // Remove the native splash now that the first page is rendered.
            FlutterNativeSplash.remove();
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // Ignore subresource errors (ads, tracking pixels, etc.).
            // Only surface main-frame failures.
            if (error.isForMainFrame ?? false) {
              FlutterNativeSplash.remove();
              if (mounted) setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (request) {
            // Allow all in-app navigation and external resource loads.
            // Block nothing — the app needs Firebase, Catbox, etc.
            return NavigationDecision.navigate;
          },
        ),
      )

      // ── JavaScript channels ───────────────────────────────────────────────
      // Allow the React app to trigger native download via:
      //   window.FlutterDownload.postMessage(JSON.stringify({ url, filename }))
      ..addJavaScriptChannel(
        'FlutterDownload',
        onMessageReceived: (msg) => _handleDownloadRequest(msg.message),
      )

      // Allow React app to check online status:
      //   window.FlutterConnectivity.postMessage('check')
      ..addJavaScriptChannel(
        'FlutterConnectivity',
        onMessageReceived: (_) {
          _controller.runJavaScript(
            'window.__flutterIsOnline = ${!_isOffline};',
          );
        },
      );

    // ── Load from local assets ───────────────────────────────────────────────
    // loadFlutterAsset is the correct API for bundled assets in webview_flutter
    // 4.x. It serves files with the right MIME types and handles relative paths
    // (CSS, JS, images) automatically.
    await _controller.loadFlutterAsset(_localIndexPath);
  }

  // ─── Permissions ──────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.videos,
    ].request();
  }

  // ─── Download handling ────────────────────────────────────────────────────
  Future<void> _handleDownloadRequest(String message) async {
    try {
      // Expect JSON: { "url": "...", "filename": "..." }
      final parts = message.replaceAll('{', '').replaceAll('}', '').split(',');
      String url = '';
      String filename = 'download';

      for (final part in parts) {
        if (part.contains('"url"')) {
          url = part.split(':').last.trim().replaceAll('"', '');
        }
        if (part.contains('"filename"')) {
          filename = part.split(':').last.trim().replaceAll('"', '');
        }
      }

      if (url.isEmpty) return;

      final storageOk = await Permission.storage.request().isGranted;
      if (!storageOk) return;

      final dir = await getExternalStorageDirectory();
      if (dir == null) return;

      await FlutterDownloader.enqueue(
        url: url,
        savedDir: dir.path,
        fileName: filename,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );
    } catch (e) {
      debugPrint('[Download] Error: $e');
    }
  }

  // ─── Reload ───────────────────────────────────────────────────────────────
  Future<void> _reloadWebView() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _controller.loadFlutterAsset(_localIndexPath);
  }

  // ─── Back button ──────────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false; // Consume the event — stay in app.
    }
    // Show an "Exit?" dialog instead of hard-exiting.
    return await _showExitDialog() ?? false;
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit LinkUp?'),
        content: const Text('Do you want to exit the app?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause/resume Firebase listeners & animations when backgrounded.
    if (state == AppLifecycleState.resumed) {
      _controller.runJavaScript(
        'document.dispatchEvent(new Event("visibilitychange"));',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub.cancel();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // bottom: false lets the app's own bottom nav sit flush with the
          // device navigation gesture bar.
          bottom: false,
          child: Stack(
            children: [
              // ── Main WebView ─────────────────────────────────────────────
              WebViewWidget(controller: _controller),

              // ── Top progress bar ─────────────────────────────────────────
              if (_isLoading && _loadingProgress > 0 && _loadingProgress < 1)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

              // ── Offline banner ───────────────────────────────────────────
              if (_isOffline)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _OfflineBanner(onRetry: _reloadWebView),
                ),

              // ── Error overlay ────────────────────────────────────────────
              if (_hasError && !_isLoading)
                _ErrorOverlay(
                  isOffline: _isOffline,
                  onRetry: _reloadWebView,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline banner widget
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'You\'re offline. Some features may be unavailable.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error overlay widget
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  final bool isOffline;
  final VoidCallback onRetry;

  const _ErrorOverlay({required this.isOffline, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                isOffline ? 'No Internet Connection' : 'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isOffline
                    ? 'Please check your connection and try again.\nThe app will reload automatically when you\'re back online.'
                    : 'Unable to load LinkUp. Please try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// File generated based on original Firebase config from the React project.
// Replace these values with your own if needed, or run `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // --- WEB ---
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBuhDDOQA2vJOfwL2KBTH3d_xbp3AlbjPg',
    authDomain: 'linkup-c22fa.firebaseapp.com',
    projectId: 'linkup-c22fa',
    storageBucket: 'linkup-c22fa.firebasestorage.app',
    messagingSenderId: '1030175932136',
    appId: '1:1030175932136:web:8f105f9279379ccb5a535d',
    measurementId: 'G-4XE0CXFGXD',
  );

  // --- ANDROID ---
  // TODO: Replace with your google-services.json values after running `flutterfire configure`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBuhDDOQA2vJOfwL2KBTH3d_xbp3AlbjPg',
    appId: '1:1030175932136:android:REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: '1030175932136',
    projectId: 'linkup-c22fa',
    storageBucket: 'linkup-c22fa.firebasestorage.app',
  );

  // --- iOS ---
  // TODO: Replace with your GoogleService-Info.plist values after running `flutterfire configure`
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBuhDDOQA2vJOfwL2KBTH3d_xbp3AlbjPg',
    appId: '1:1030175932136:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '1030175932136',
    projectId: 'linkup-c22fa',
    storageBucket: 'linkup-c22fa.firebasestorage.app',
    iosBundleId: 'com.example.linkup',
  );
}

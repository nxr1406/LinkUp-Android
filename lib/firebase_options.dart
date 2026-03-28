import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDGMnVNU7G-59HsxXY0bM_kdRxmpgOx5Bs',
    appId: '1:1030175932136:android:2d6e3c873e726ad05a535d',
    messagingSenderId: '1030175932136',
    projectId: 'linkup-c22fa',
    storageBucket: 'linkup-c22fa.firebasestorage.app',
    databaseURL: 'https://linkup-c22fa-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDGMnVNU7G-59HsxXY0bM_kdRxmpgOx5Bs',
    appId: '1:1030175932136:ios:2d6e3c873e726ad05a535d',
    messagingSenderId: '1030175932136',
    projectId: 'linkup-c22fa',
    storageBucket: 'linkup-c22fa.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGMnVNU7G-59HsxXY0bM_kdRxmpgOx5Bs',
    appId: '1:1030175932136:web:2d6e3c873e726ad05a535d',
    messagingSenderId: '1030175932136',
    projectId: 'linkup-c22fa',
    storageBucket: 'linkup-c22fa.firebasestorage.app',
  );
}

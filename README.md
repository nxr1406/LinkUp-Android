# LinkUp Flutter — সম্পূর্ণ সেটআপ গাইড

## এই অ্যাপে যা যা আছে

- ✅ Login / Register (email + username দিয়ে)
- ✅ Real-time Chat (reply, delete, emoji)
- ✅ Chat List (unread badge, online indicator)
- ✅ User Search
- ✅ Profile Edit (ছবি Catbox-এ আপলোড)
- ✅ Verified Badge
- ✅ Suspended Account + Appeal System
- ✅ Blocked Users
- ✅ Admin Panel (verification + appeals)
- ✅ Firebase Firestore rules

---

## ধাপ ১ — প্রয়োজনীয় সফটওয়্যার

```bash
# Flutter SDK ইন্সটল করুন
https://docs.flutter.dev/get-started/install

# Android Studio ইন্সটল করুন
https://developer.android.com/studio

# FlutterFire CLI ইন্সটল করুন
dart pub global activate flutterfire_cli
```

---

## ধাপ ২ — Firebase প্রজেক্ট তৈরি

1. https://console.firebase.google.com এ যান
2. **"Add project"** ক্লিক করুন → প্রজেক্টের নাম দিন
3. **Authentication** চালু করুন:
   - Authentication → Sign-in method → Email/Password → Enable
4. **Firestore Database** চালু করুন:
   - Firestore Database → Create database → Start in test mode
5. **Storage** চালু করুন (optional, আমরা Catbox ব্যবহার করছি)

---

## ধাপ ৩ — Firebase কানেক্ট করুন

প্রজেক্ট ফোল্ডারে Terminal খুলুন:

```bash
cd linkup_flutter

# Firebase লগইন করুন
firebase login

# FlutterFire configure চালান
flutterfire configure
```

এই কমান্ড চালালে `lib/firebase_options.dart` ফাইলটি **অটোমেটিক** আপডেট হবে।
(আগে থেকে থাকা placeholder ফাইলটি replace হয়ে যাবে)

---

## ধাপ ৪ — Firestore Rules আপলোড করুন

```bash
# Firebase CLI ইন্সটল থাকলে:
firebase deploy --only firestore:rules

# অথবা Firebase Console-এ গিয়ে firestore.rules ফাইলের কনটেন্ট paste করুন
# Firestore → Rules → Edit → Publish
```

---

## ধাপ ৫ — Dependencies ইন্সটল করুন

```bash
flutter pub get
```

---

## ধাপ ৬ — অ্যাপ রান করুন

```bash
# Android emulator বা real device কানেক্ট করুন, তারপর:
flutter run

# শুধু Android-এর জন্য APK বানাতে:
flutter build apk --release
# APK পাবেন: build/app/outputs/flutter-apk/app-release.apk
```

---

## প্রজেক্ট স্ট্রাকচার

```
lib/
├── main.dart                    # Entry point + Router
├── firebase_options.dart        # Firebase config (auto-generated)
├── providers/
│   └── auth_provider.dart       # Auth state management
├── screens/
│   ├── login_screen.dart        # Login page
│   ├── register_screen.dart     # Registration page
│   ├── main_layout.dart         # Bottom nav shell
│   ├── home_screen.dart         # Chat list
│   ├── chat_screen.dart         # Messaging screen
│   ├── search_screen.dart       # User search
│   ├── profile_screen.dart      # My profile
│   ├── user_profile_screen.dart # Other user's profile
│   ├── notifications_screen.dart
│   ├── blocked_users_screen.dart
│   ├── suspended_screen.dart    # Suspended account
│   ├── privacy_screen.dart
│   ├── admin_verification_screen.dart
│   └── admin_appeals_screen.dart
├── widgets/
│   ├── avatar_widget.dart       # Profile picture widget
│   ├── verified_badge.dart      # Blue tick
│   └── loading_widget.dart      # Loaders + toast helper
└── services/
    └── catbox_service.dart      # Image upload service
```

---

## সাধারণ সমস্যা ও সমাধান

### `google-services.json` না পেলে
- Firebase Console → Project Settings → Your apps → Android → Download google-services.json
- ফাইলটি `android/app/` ফোল্ডারে রাখুন

### Build error: minSdkVersion
`android/app/build.gradle`-এ এই লাইন আছে কিনা দেখুন:
```gradle
minSdkVersion 21
```

### Image pick কাজ না করলে
`android/app/src/main/AndroidManifest.xml`-এ permission আছে কিনা চেক করুন।

### iOS-এ চালাতে হলে
`ios/Runner/Info.plist`-এ যোগ করুন:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access for profile picture</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for profile picture</string>
```

---

## Admin ব্যবহারকারী তৈরি

Firebase Console → Firestore → `users` collection-এ আপনার user document খুলুন → `role` field-এর value `"admin"` করুন।

---

## Firebase Indexes

Chat list ঠিকমতো কাজ করতে Firestore-এ Composite Index লাগতে পারে। Console-এ এরর দিলে দেওয়া link-এ ক্লিক করে index তৈরি করুন।

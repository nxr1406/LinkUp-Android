# LinkUp Flutter App

Instagram-style ephemeral messaging app — messages auto-delete after 24 hours.

## Project Structure

```
lib/
├── main.dart                         # Entry point
├── router.dart                       # GoRouter navigation
├── firebase_options.dart             # Firebase config
├── models/
│   ├── user_model.dart
│   └── chat_model.dart               # Chat + Message + Notification models
├── providers/
│   └── auth_provider.dart            # Auth state (ChangeNotifier)
├── services/
│   └── catbox_service.dart           # Profile picture upload
├── utils/
│   ├── theme.dart                    # Colors, AppTheme
│   └── helpers.dart                  # Time formatters
├── widgets/
│   └── user_avatar.dart              # Reusable avatar widget
└── screens/
    ├── login_screen.dart
    ├── register_screen.dart
    ├── main_layout.dart              # Bottom nav shell
    ├── home_screen.dart              # Chat list + Active users
    ├── search_screen.dart            # Find users
    ├── chat_screen.dart              # Full messaging UI
    ├── profile_screen.dart           # Own profile + edit
    ├── user_profile_screen.dart      # View others + block
    ├── notifications_screen.dart
    ├── blocked_users_screen.dart
    └── privacy_screen.dart
```

## Setup Steps

### 1. Flutter & Firebase setup
```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure --project=linkup-c22fa
```

This will generate a new `firebase_options.dart` with correct Android/iOS app IDs
and download `google-services.json` for Android.

### 2. Run
```bash
flutter run
```

### 3. Build APK
```bash
flutter build apk --release
```

## Features
- ✅ Email/Username login
- ✅ Registration with profile picture upload (Catbox)
- ✅ Real-time chat with Firestore
- ✅ 24-hour auto-expiring messages
- ✅ Reply to messages
- ✅ Edit / Delete messages
- ✅ Read receipts (✓✓)
- ✅ Typing indicator
- ✅ Active users (online status)
- ✅ User search
- ✅ View user profiles
- ✅ Block / Unblock users
- ✅ Edit own profile
- ✅ Notifications
- ✅ Delete account
- ✅ Offline/Online status tracking

## Tech Stack
- Flutter 3 + Dart
- Firebase Auth + Firestore
- Provider (state management)
- GoRouter (navigation)
- cached_network_image
- image_picker
- http (Catbox upload)

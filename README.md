<div align="center">

# 💬 LinkUp

### A Real-Time Chat Application Built with Flutter & Firebase

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.27.0-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<br/>

> **LinkUp** is a feature-rich, production-ready real-time chat application designed with a modern pink blob aesthetic, built by **RI Nirob Sarkar ([@nxr1406](https://github.com/nxr1406))**.  
> It leverages Firebase Firestore for real-time messaging and authentication, with a fully custom admin panel, verified badge system, and account moderation tools — all without Firebase Storage.

<br/>

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Firestore Collections](#-firestore-collections)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Clone the Repository](#1-clone-the-repository)
  - [Firebase Setup](#2-firebase-setup)
  - [Run the App](#3-run-the-app)
- [Firebase Security Rules](#-firebase-security-rules)
- [GitHub Actions — CI/CD](#-github-actions--cicd)
- [Environment & Configuration](#-environment--configuration)
- [Known Limitations](#-known-limitations)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [Author](#-author)
- [License](#-license)

---

## 🌟 Overview

LinkUp is designed to demonstrate a complete, end-to-end chat application architecture using Flutter and Firebase. The app features user authentication, real-time messaging, profile management with image compression, a verified badge system with an admin review flow, and a full account moderation system including suspensions and appeals.

**Key design decisions:**
- ✅ **No Firebase Storage** — all images (profile photos) are stored directly in Firestore as compressed base64 strings, eliminating the need for a Storage bucket and keeping the setup minimal.
- ✅ **No third-party state management** — minimal dependencies, uses Flutter's built-in `setState` and `StreamBuilder` patterns.
- ✅ **Production-ready rules** — includes `firestore.rules` and `firestore.indexes.json` for deployment.

---

## ✨ Features

### 🔐 Authentication
- Email and password registration and login via Firebase Auth
- Persistent login session across app restarts
- Secure logout from any screen

### 💬 Real-Time Messaging
- Instant message delivery powered by Firestore's real-time listeners
- Chat room creation between any two users
- Last message preview and timestamp shown in chat list
- Unread message count badge per conversation
- Messages sorted chronologically with auto-scroll to latest

### 👤 User Profiles
- Customizable username and display name
- Profile photo upload with client-side **WebP/JPEG compression** (256×256px, quality 60) before storing in Firestore as base64
- User bio/about section
- Profile viewing for other users

### ✅ Verified Badge System
- Users can submit a **verification request** from their profile
- Admins review pending requests in the Admin Panel
- Approve or reject with one tap
- Verified badge (`✅`) displayed on profile and in chat

### 🛡️ Admin Panel
- Accessible only to accounts with `isAdmin: true` in Firestore
- **User management:** view all users, inspect profiles, suspend or unsuspend accounts
- **Verification queue:** review and act on pending verification requests
- **Appeals queue:** review and resolve suspension appeal submissions
- All actions are logged with timestamps

### 🚫 Account Suspension & Appeal System
- Admins can suspend any user with a reason
- Suspended users see a dedicated suspension screen on login with their reason
- Suspended users can submit an **appeal** explaining their case
- Admins can approve appeals (automatically unsuspends) or reject them

### 🔍 User Search
- Search users by username in real time
- Results update as you type
- Tap a result to view their profile or start a chat

### 🎨 UI/UX
- Custom **pink blob** design language, matching the original Figma concept
- Smooth page transitions and responsive layouts
- Bottom navigation bar with Home, Search, and Profile tabs
- Loading indicators and empty-state illustrations throughout

---

## 🛠 Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| **Frontend** | Flutter 3.27.0 | Cross-platform (Android + iOS) |
| **Language** | Dart 3.x | |
| **Authentication** | Firebase Auth | Email/password only |
| **Database** | Cloud Firestore | Real-time listeners |
| **Image Compression** | `image` package | WebP/JPEG, 256×256, quality 60 |
| **Push Notifications** | *(see Roadmap)* | FCM integration planned |
| **CI/CD** | GitHub Actions | APK build + GitHub Releases |

### Flutter Packages Used

```yaml
dependencies:
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
  image: ^latest                  # Client-side image compression
  image_picker: ^latest           # Gallery/camera access for avatar
  cached_network_image: ^latest   # (if applicable)
  intl: ^latest                   # Date/time formatting
```

---

## 📁 Project Structure

```
linkup/
├── android/
│   └── app/
│       └── google-services.json        # Firebase config (Android)
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist    # Firebase config (iOS)
├── lib/
│   ├── main.dart                       # App entry point
│   ├── firebase_options.dart           # FlutterFire config
│   │
│   ├── models/                         # Data models
│   │   ├── user_model.dart
│   │   ├── message_model.dart
│   │   ├── chat_model.dart
│   │   └── appeal_model.dart
│   │
│   ├── screens/                        # UI screens
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart        # Chat list
│   │   ├── chat/
│   │   │   └── chat_screen.dart        # Individual chat room
│   │   ├── profile/
│   │   │   ├── profile_screen.dart     # Own profile
│   │   │   └── view_profile_screen.dart
│   │   ├── search/
│   │   │   └── search_screen.dart
│   │   ├── admin/
│   │   │   └── admin_panel_screen.dart
│   │   └── suspension/
│   │       └── suspended_screen.dart
│   │
│   ├── services/                       # Firebase service layer
│   │   ├── auth_service.dart
│   │   ├── chat_service.dart
│   │   ├── user_service.dart
│   │   └── admin_service.dart
│   │
│   └── widgets/                        # Reusable UI components
│       ├── verified_badge.dart
│       ├── user_avatar.dart
│       └── chat_bubble.dart
│
├── firestore.rules                     # Firestore security rules
├── firestore.indexes.json              # Composite indexes
├── .github/
│   └── workflows/
│       └── build.yml                   # GitHub Actions workflow
└── pubspec.yaml
```

---

## 🗄 Firestore Collections

### `users`
Stores all user profile data.

```json
{
  "uid": "string",
  "email": "string",
  "username": "string",
  "displayName": "string",
  "bio": "string",
  "photoBase64": "string",        // Compressed base64 JPEG (~256x256, quality 60)
  "isVerified": false,
  "isAdmin": false,
  "isSuspended": false,
  "suspensionReason": "string",
  "createdAt": "Timestamp"
}
```

### `chats`
Metadata for each chat room between two participants.

```json
{
  "participants": ["uid1", "uid2"],
  "participantDetails": {
    "uid1": { "username": "...", "photoBase64": "..." },
    "uid2": { "username": "...", "photoBase64": "..." }
  },
  "lastMessage": "string",
  "lastMessageTime": "Timestamp",
  "unreadCount": {
    "uid1": 0,
    "uid2": 2
  }
}
```

### `chats/{chatId}/messages`
Individual messages within a chat room.

```json
{
  "senderId": "string",
  "text": "string",
  "sentAt": "Timestamp",
  "readBy": ["uid1"]
}
```

### `verification_requests`
Submitted by users who want to get verified.

```json
{
  "userId": "string",
  "username": "string",
  "reason": "string",
  "status": "pending | approved | rejected",
  "submittedAt": "Timestamp",
  "reviewedAt": "Timestamp",
  "reviewedBy": "string"
}
```

### `suspension_appeals`
Submitted by suspended users appealing their suspension.

```json
{
  "userId": "string",
  "username": "string",
  "appealText": "string",
  "status": "pending | approved | rejected",
  "submittedAt": "Timestamp",
  "reviewedAt": "Timestamp",
  "reviewedBy": "string"
}
```

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `3.27.0` or higher
- [Dart SDK](https://dart.dev/get-dart) `3.x`
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter plugin
- A [Firebase](https://firebase.google.com/) project (free Spark plan is sufficient)
- `flutterfire` CLI (optional, for re-configuring Firebase)

```bash
flutter --version   # Verify Flutter installation
dart --version      # Verify Dart installation
```

---

### 1. Clone the Repository

```bash
git clone https://github.com/nxr1406/linkup.git
cd linkup
flutter pub get
```

---

### 2. Firebase Setup

#### A. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/) → **Add project**
2. Enable **Authentication** → Sign-in method → **Email/Password**
3. Enable **Cloud Firestore** → Start in **production mode**

#### B. Android Configuration
The `android/app/google-services.json` is already included for the package `com.nxr.linkup`.

If you're using your **own** Firebase project:
1. Register your Android app with package name `com.nxr.linkup`
2. Download the new `google-services.json`
3. Replace `android/app/google-services.json`

#### C. iOS Configuration *(optional)*
1. Register your iOS app with bundle ID `com.nxr.linkup`
2. Download `GoogleService-Info.plist`
3. Place it inside `ios/Runner/`

#### D. Deploy Firestore Rules & Indexes

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login and initialize
firebase login
firebase init firestore

# Deploy rules and indexes
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

---

### 3. Run the App

```bash
# Check connected devices
flutter devices

# Run on a connected device or emulator
flutter run

# Run in release mode
flutter run --release

# Build APK
flutter build apk --release
```

The release APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔒 Firebase Security Rules

Below is a summary of the `firestore.rules` logic:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: readable by anyone logged in, writable only by self
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // Chats: accessible only by participants
    match /chats/{chatId} {
      allow read, write: if request.auth.uid in resource.data.participants;

      match /messages/{messageId} {
        allow read, write: if request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
      }
    }

    // Verification requests: user can create, admin can update
    match /verification_requests/{reqId} {
      allow create: if request.auth != null;
      allow read, update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    // Suspension appeals: same as verification
    match /suspension_appeals/{appealId} {
      allow create: if request.auth != null;
      allow read, update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

> ⚠️ Remember to deploy the actual `firestore.rules` file from the repo — the above is a summarized version.

---

## ⚙️ GitHub Actions — CI/CD

The project includes a GitHub Actions workflow that automatically builds a release APK on every push to `main`/`master`, and publishes a GitHub Release when a version tag is pushed.

### Setup: Add the Required Secret

1. Go to your repository → **Settings → Secrets and variables → Actions → New repository secret**
2. Name: `GOOGLE_SERVICES_JSON`
3. Value: Paste the **entire contents** of your `android/app/google-services.json`

### Workflow Triggers

| Trigger | Action |
|---------|--------|
| Push to `main` or `master` | Builds APK, uploads as workflow artifact |
| Push a tag (e.g. `v1.0.0`) | Builds APK, creates a **GitHub Release** with APK attached |

### Creating a Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

This will trigger the workflow and automatically create a release at:  
`https://github.com/nxr1406/linkup/releases/tag/v1.0.0`

---

## 🔧 Environment & Configuration

### Making an Account an Admin

Admins are set manually in Firestore. To grant admin access:

1. Open Firebase Console → Firestore
2. Navigate to `users/{uid}`
3. Set `isAdmin` field to `true`

### Image Compression Settings

Profile images are compressed on the client before being stored. Current settings (adjustable in `user_service.dart`):

| Setting | Value |
|---------|-------|
| Max width | 256 px |
| Max height | 256 px |
| Format | JPEG |
| Quality | 60 |
| Storage | Firestore as base64 string |

> ⚠️ **Note:** Storing images as base64 in Firestore increases document size significantly. Each profile photo can be ~30–60 KB. This works well for small apps but may increase Firestore read costs at scale. Consider migrating to Firebase Storage for production at scale.

---

## ⚠️ Known Limitations

| Limitation | Details |
|---|---|
| **Text-only chat** | Camera and microphone buttons in the chat UI are decorative and non-functional. Only text messages are supported. |
| **No push notifications** | The app currently has no FCM-based push notifications. A backend is planned (see Roadmap). |
| **Base64 image storage** | All images stored in Firestore as base64. Not ideal for large user bases due to Firestore document size and bandwidth costs. |
| **Single device session** | No multi-device session management. Logging in on a new device does not invalidate the previous session. |
| **No message deletion** | Users cannot delete sent messages. |
| **No group chats** | Only 1-on-1 conversations are supported. |

---

## 🗺 Roadmap

- [ ] **Push Notifications** — FCM integration with a Django backend (in progress)
- [ ] **Media Messages** — Image and file sharing in chat
- [ ] **Group Chats** — Multi-participant conversations
- [ ] **Message Reactions** — Emoji reactions on messages
- [ ] **Read Receipts** — Double-tick indicators like WhatsApp
- [ ] **Message Deletion** — Delete for self or everyone
- [ ] **Voice Messages** — Record and send audio clips
- [ ] **Dark Mode** — System-aware dark theme
- [ ] **Migrate to Firebase Storage** — Move profile photos out of Firestore documents
- [ ] **Online/Offline Status** — Show real-time presence indicators

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Commit** your changes: `git commit -m 'feat: add your feature'`
4. **Push** to the branch: `git push origin feature/your-feature-name`
5. **Open a Pull Request**

Please follow the existing code style and include meaningful commit messages.

---

## 👤 Author

**RI Nirob Sarkar**

- GitHub: [@nxr1406](https://github.com/nxr1406)
- Project: [LinkUp](https://github.com/nxr1406/linkup)

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with Flutter by **RI Nirob Sarkar**

⭐ Star this repo if you found it helpful!

</div>

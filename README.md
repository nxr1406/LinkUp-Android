# LinkUp 💬

A real-time chat app built with Flutter + Firebase Firestore by **RI Nirob Sarkar (@nxrdev)**.

---

## Features

- 🔐 Email/password authentication
- 💬 Real-time text messaging (Firestore)
- 👤 User profiles with WebP-compressed avatar (stored in Firestore, no Storage)
- ✅ Verified badge system (request + admin review)
- 🛡️ Admin panel (manage users, verifications, suspension appeals)
- 🚫 Account suspension + appeal system
- 🔍 User search by username
- 📱 Pink blob UI design (matching Figma concept)

---

## Setup

### 1. Clone the repo
```bash
git clone https://github.com/YOUR_USERNAME/linkup.git
cd linkup
flutter pub get
```

### 2. Firebase Setup
- The `android/app/google-services.json` is included for the `com.nxr.linkup` package.
- In Firebase Console → Firestore → deploy `firestore.rules` and `firestore.indexes.json`.

### 3. Run locally
```bash
flutter run
```

---

## GitHub Actions — Build APK

### Add Secret
1. Go to **Settings → Secrets → Actions → New repository secret**
2. Name: `GOOGLE_SERVICES_JSON`
3. Value: paste the entire contents of your `google-services.json`

### Trigger a build
- Push to `main`/`master` → uploads APK as artifact
- Push a tag like `v1.0.0` → creates a GitHub Release with APK attached

---

## Firestore Collections

| Collection | Description |
|---|---|
| `users` | User profiles (photoBase64, isVerified, isAdmin, etc.) |
| `chats` | Chat metadata (participants, lastMessage, unreadCount) |
| `chats/{id}/messages` | Individual messages |
| `verification_requests` | Verification requests |
| `suspension_appeals` | Suspension appeal requests |

---

## Tech Stack

- **Flutter** 3.24+
- **Firebase Auth** — email/password
- **Cloud Firestore** — all data including images as base64
- **image** package — WebP/JPEG compression before storing

---

## Notes

- No Firebase Storage used — all images stored as base64 JPEG in Firestore (compressed to ~256×256, quality 60)
- Camera/mic buttons in chat UI are decorative only (text-only chat)
- Only profile picture upload is functional

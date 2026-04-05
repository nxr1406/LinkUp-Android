# Music Player - Flutter

## GitHub Actions দিয়ে Release APK Build করার নিয়ম

### ধাপ ১ — Keystore তৈরি করো (একবারই করতে হবে)

```bash
keytool -genkey -v \
  -keystore my-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias my-key-alias
```

তুমি যে password দেবে সেটা মনে রেখো।

---

### ধাপ ২ — Keystore কে Base64 করো

**Linux/Mac:**
```bash
base64 -i my-release-key.jks | tr -d '\n'
```

**Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("my-release-key.jks"))
```

এই output টা copy করে রাখো।

---

### ধাপ ৩ — GitHub Secrets সেট করো

GitHub রেপোতে যাও → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

নিচের ৪টা secret যোগ করো:

| Secret Name | মান |
|---|---|
| `KEYSTORE_BASE64` | ধাপ ২-এর Base64 output |
| `STORE_PASSWORD` | keystore বানানোর সময় দেওয়া password |
| `KEY_PASSWORD` | key-এর password (সাধারণত একই) |
| `KEY_ALIAS` | `my-key-alias` (তুমি যেটা দিয়েছিলে) |

---

### ধাপ ৪ — Push করো

```bash
git add .
git commit -m "Add release build workflow"
git push origin main
```

GitHub Actions অটো চালু হবে।

---

### ✅ APK কোথায় পাবে

**Actions** ট্যাব → সেই workflow run → নিচে **Artifacts**:

- `release-apk-armeabi-v7a` → পুরনো ARM ফোনের জন্য
- `release-apk-arm64-v8a` → নতুন 64-bit ফোনের জন্য

---

### ফাইল স্ট্রাকচার

```
music_player/
├── .github/
│   └── workflows/
│       └── build_apk.yml       ← CI/CD workflow
├── android/
│   ├── app/
│   │   ├── build.gradle        ← signing config + ABI splits
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/.../MainActivity.kt
│   │       └── res/
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradle.properties
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── queue_screen.dart
│   │   ├── now_playing_screen.dart
│   │   └── album_screen.dart
│   └── models/
│       └── song_data.dart
└── pubspec.yaml
```

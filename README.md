# LinkUp Flutter WebView App

Convert your Vite + React PWA into a Flutter Android app.

---

## What this does

Your app is bundled as **static files** (HTML / CSS / JS) inside the Flutter
APK. The Flutter shell loads them via `loadFlutterAsset()` — no server needed.
Firebase and the Gemini API still connect over the internet as usual; only the
*app shell* is served offline.

```
Android APK
└── assets/
    └── www/               ← Vite `dist/` output lives here
        ├── index.html
        ├── assets/
        │   ├── js/
        │   ├── css/
        │   └── img/
        └── ...
```

---

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| Flutter SDK | 3.19 | https://docs.flutter.dev/get-started/install |
| Android Studio | Hedgehog+ | https://developer.android.com/studio |
| Node.js | 18 LTS | https://nodejs.org |
| Java (JDK) | 17 | bundled with Android Studio |

Verify your Flutter setup:
```bash
flutter doctor
```
All items should be green before proceeding.

---

## Step 1 — Build the Vite / React app

### 1a. Copy the updated vite.config.ts

Replace your existing `vite.config.ts` with the one in this package.
The key change is `base: './'` — mandatory for `file://` / asset loading.

### 1b. Install dependencies
```bash
cd LinkUp-Dev-Ac2-main
npm install
```

### 1c. Set up your .env file
```bash
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY
```

### 1d. Build
```bash
npm run build
# Output: dist/
```

### 1e. Copy dist/ into Flutter assets
```bash
rm -rf linkup_flutter/assets/www
cp -r dist/ linkup_flutter/assets/www/
```

---

## Step 2 — Set up the Flutter project

### 2a. Get packages
```bash
cd linkup_flutter
flutter pub get
```

### 2b. Add your app icons

Place a 1024×1024 PNG at:
- `assets/icon/icon.png`
- `assets/icon/icon_foreground.png`  (transparent, for adaptive icon)

Then generate:
```bash
flutter pub run flutter_launcher_icons
```

### 2c. Add your splash logo

Place your logo PNG at:
- `assets/splash/splash_logo.png`
- `assets/splash/splash_logo_dark.png`

Also copy it to:
```
android/app/src/main/res/drawable/splash_logo.png
```

Then generate the native splash:
```bash
dart run flutter_native_splash:create
```

---

## Step 3 — Configure android/app/build.gradle

Open `android/app/build.gradle` and update:

```groovy
android {
    namespace "com.linkup.app"
    compileSdk 35

    defaultConfig {
        applicationId "com.linkup.app"
        minSdk 21
        targetSdk 35
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release  // see keystore section
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

## Step 4 — Build the APK

### Debug APK (for testing)
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

Install on a connected device:
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK (for Play Store / sideload)

#### 4a. Create a keystore (one-time setup)
```bash
keytool -genkey -v \
  -keystore android/linkup-release.jks \
  -alias linkup \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

#### 4b. Create android/key.properties
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=linkup
storeFile=../linkup-release.jks
```

#### 4c. Reference it in android/app/build.gradle
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### 4d. Build split APKs (smaller downloads)
```bash
flutter build apk --release --split-per-abi
# Outputs:
#   app-armeabi-v7a-release.apk   (~32-bit devices)
#   app-arm64-v8a-release.apk     (~most modern phones)
#   app-x86_64-release.apk        (~emulators)
```

---

## One-command build (after setup)

```bash
chmod +x build_and_deploy.sh
./build_and_deploy.sh           # debug
./build_and_deploy.sh --release # release
```

---

## Project structure

```
linkup_flutter/
├── lib/
│   ├── main.dart              ← App entry, theme, orientation lock
│   └── webview_screen.dart    ← WebView, offline handling, downloads
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       ├── kotlin/com/linkup/app/
│       │   └── MainActivity.kt
│       └── res/
│           ├── drawable/launch_background.xml
│           ├── values/styles.xml
│           └── xml/provider_paths.xml
├── assets/
│   ├── www/                   ← ← ← Paste your dist/ here
│   ├── icon/
│   └── splash/
├── pubspec.yaml
├── vite.config.ts             ← Updated config for static export
└── build_and_deploy.sh        ← Automation script
```

---

## Features implemented

| Feature | Implementation |
|---------|---------------|
| Offline app shell | Static assets bundled in APK via `loadFlutterAsset()` |
| Firebase / API calls | Work over the internet as normal |
| Back navigation | `PopScope` + WebView history stack |
| Exit confirmation | Dialog shown when at root of history |
| Offline banner | `connectivity_plus` stream listener |
| Error overlay | Main-frame errors with retry button |
| Loading indicator | `LinearProgressIndicator` driven by `onProgress` |
| File upload | Camera + storage permissions + WebView file picker |
| File download | `flutter_downloader` triggered via JS channel |
| Edge-to-edge | `SystemUiMode.edgeToEdge` |
| Splash screen | `flutter_native_splash` |
| App icon | `flutter_launcher_icons` |
| Portrait lock | `SystemChrome.setPreferredOrientations` |

---

## Troubleshooting

**"MissingPluginException" on first run**
→ Run `flutter pub get` then `flutter clean && flutter run`.

**White screen after splash**
→ Check that `assets/www/index.html` exists. Run `flutter pub get` after
  adding files to pubspec.yaml.

**Firebase auth fails**
→ The app uses your hardcoded Firebase config in `src/firebase.ts`.
  Make sure your Firebase project allows the `file://` origin, or use
  `signInWithRedirect` instead of `signInWithPopup`.

**File picker doesn't open**
→ Ensure camera and storage permissions are granted in device settings.

**App crashes on Android 12+**
→ Make sure `android:exported="true"` is set on MainActivity (already done).

---

## Updating the web app

1. Make changes in `LinkUp-Dev-Ac2-main/src/`
2. Run `npm run build`
3. Copy `dist/` → `assets/www/`
4. Run `flutter build apk`

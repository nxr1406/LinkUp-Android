#!/usr/bin/env bash
# =============================================================================
# build_and_deploy.sh
# Full pipeline: Vite build → copy to Flutter assets → build APK
#
# Usage:
#   chmod +x build_and_deploy.sh
#   ./build_and_deploy.sh              # debug APK
#   ./build_and_deploy.sh --release    # release APK (needs keystore)
# =============================================================================

set -euo pipefail

# ── Paths (edit if your directories differ) ───────────────────────────────────
NEXTJS_DIR="$(pwd)/LinkUp-Dev-Ac2-main"   # Your Vite/React source
FLUTTER_DIR="$(pwd)/linkup_flutter"        # Flutter project root
ASSETS_WWW="${FLUTTER_DIR}/assets/www"

BUILD_MODE="${1:-}"  # "--release" or empty for debug

# ─────────────────────────────────────────────────────────────────────────────
# 0. Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────
echo "🔍 Checking tools..."
command -v node  >/dev/null 2>&1 || { echo "❌ node not found"; exit 1; }
command -v npm   >/dev/null 2>&1 || { echo "❌ npm not found";  exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "❌ flutter not found"; exit 1; }
echo "✅ node $(node --version), npm $(npm --version), flutter $(flutter --version | head -1)"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Build the Vite / React app
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "📦 Step 1 — Building Vite / React app..."
cd "${NEXTJS_DIR}"

# Install deps if node_modules is missing or stale.
if [ ! -d "node_modules" ]; then
  echo "   Installing npm dependencies..."
  npm install
fi

# Copy the Flutter-optimised vite.config.ts if you haven't already.
# (Assumes vite.config.ts is already updated with base: './')

npm run build
echo "   ✅ Vite build complete → dist/"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Copy build output into Flutter assets
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "📋 Step 2 — Copying dist/ → flutter/assets/www/..."
rm -rf "${ASSETS_WWW}"
mkdir -p "${ASSETS_WWW}"
cp -r "${NEXTJS_DIR}/dist/." "${ASSETS_WWW}/"
echo "   ✅ Files copied to ${ASSETS_WWW}"

# Count files for sanity check.
FILE_COUNT=$(find "${ASSETS_WWW}" -type f | wc -l)
echo "   📄 ${FILE_COUNT} files in assets/www/"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Flutter setup
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "🐦 Step 3 — Setting up Flutter..."
cd "${FLUTTER_DIR}"
flutter pub get
echo "   ✅ Flutter packages resolved"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Build APK
# ─────────────────────────────────────────────────────────────────────────────
echo ""
if [ "${BUILD_MODE}" = "--release" ]; then
  echo "🏗️  Step 4 — Building RELEASE APK..."
  echo "   ⚠️  Ensure your keystore is configured in android/key.properties"
  flutter build apk --release --split-per-abi
  echo ""
  echo "✅ Release APKs:"
  find "${FLUTTER_DIR}/build/app/outputs/flutter-apk" -name "*.apk" | while read f; do
    SIZE=$(du -h "$f" | cut -f1)
    echo "   ${SIZE}  $f"
  done
else
  echo "🏗️  Step 4 — Building DEBUG APK..."
  flutter build apk --debug
  APK_PATH="${FLUTTER_DIR}/build/app/outputs/flutter-apk/app-debug.apk"
  SIZE=$(du -h "${APK_PATH}" | cut -f1)
  echo ""
  echo "✅ Debug APK: ${SIZE}  ${APK_PATH}"
fi

echo ""
echo "🎉 Done! Install with:"
if [ "${BUILD_MODE}" = "--release" ]; then
  echo "   adb install ${FLUTTER_DIR}/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
else
  echo "   adb install ${FLUTTER_DIR}/build/app/outputs/flutter-apk/app-debug.apk"
fi

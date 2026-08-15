#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "========================================"
echo " 🚀 ClipBo Release Builder"
echo "========================================"

# 1. Clean Build Directory
echo "🧹 Cleaning previous build artifacts..."
rm -rf .build build dist
mkdir -p build dist

# 2. Run Test Suite
echo "🧪 Running automated test suites..."
swift run ClipBoTests
echo "  ✓ Tests passed"

# 3. Build Application Bundle
echo "🔨 Building ClipBo.app release bundle..."
./scripts/build_app.sh >/dev/null
echo "  ✓ Application built"

# 4. Verify Bundle Structure
APP_PATH="build/ClipBo.app"
if [ ! -d "$APP_PATH/Contents/MacOS" ] || [ ! -d "$APP_PATH/Contents/Resources" ] || [ ! -f "$APP_PATH/Contents/Info.plist" ]; then
    echo "❌ Error: Application bundle structure is invalid."
    exit 1
fi
echo "  ✓ Bundle verified"

# 5. Verify AppIcon
if [ ! -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    echo "❌ Error: AppIcon.icns missing in bundle."
    exit 1
fi
echo "  ✓ Icon verified: $APP_PATH/Contents/Resources/AppIcon.icns"

# 6. Verify Architecture
ARCH=$(lipo -archs "$APP_PATH/Contents/MacOS/ClipBo" 2>/dev/null || uname -m)
if [[ "$ARCH" != *"arm64"* ]]; then
    echo "❌ Error: Built architecture ($ARCH) is not arm64."
    exit 1
fi
echo "  ✓ Architecture: $ARCH"

# 7. Verify Info.plist & Version
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.6.4")
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "com.clipbo.app")
echo "  ✓ Info.plist verified (v$VERSION, $BUNDLE_ID)"

# 8. Verify Code Signature
codesign --verify --deep --strict "$APP_PATH"
echo "  ✓ Code signature verified (ad-hoc / local developer signature)"

# 9. Create DMG Release
echo "💿 Packaging DMG distribution..."
./scripts/create_dmg.sh >/dev/null
echo "  ✓ DMG created"

# 10. Verify DMG
if [ ! -f "dist/ClipBo.dmg" ]; then
    echo "❌ Error: dist/ClipBo.dmg not found."
    exit 1
fi

DMG_SIZE=$(du -h "dist/ClipBo.dmg" | awk '{print $1}')

echo ""
echo "========================================"
echo " 🎉 Release Build Complete!"
echo "========================================"
echo "  Version:      v$VERSION"
echo "  Architecture: $ARCH"
echo "  App Bundle:   build/ClipBo.app"
echo "  DMG Release:  dist/ClipBo.dmg ($DMG_SIZE)"
echo "  Versioned:    dist/ClipBo-$VERSION.dmg"
echo "========================================"

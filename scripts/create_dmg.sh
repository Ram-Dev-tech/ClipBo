#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_PATH="build/ClipBo.app"
DIST_DIR="dist"
VOL_NAME="ClipBo"

echo "========================================"
echo " 💿 ClipBo macOS DMG Builder"
echo "========================================"

# 1. Verify build/ClipBo.app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_PATH not found."
    echo "Please build the release application first:"
    echo "  ./scripts/build_app.sh"
    exit 1
fi

# 2. Verify bundle structure
echo "🔍 Verifying application bundle..."
if [ ! -f "$APP_PATH/Contents/MacOS/ClipBo" ]; then
    echo "❌ Error: $APP_PATH/Contents/MacOS/ClipBo executable is missing."
    exit 1
fi

if [ ! -f "$APP_PATH/Contents/Info.plist" ]; then
    echo "❌ Error: $APP_PATH/Contents/Info.plist is missing."
    exit 1
fi

if [ ! -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    echo "❌ Error: $APP_PATH/Contents/Resources/AppIcon.icns is missing."
    exit 1
fi

# 3. Verify Bundle Identifier
BUNDLE_ID=$(defaults read "$REPO_ROOT/$APP_PATH/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || plutil -extract CFBundleIdentifier raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "")
if [ "$BUNDLE_ID" != "com.clipbo.app" ]; then
    echo "❌ Error: Unexpected bundle identifier: '$BUNDLE_ID'. Expected 'com.clipbo.app'."
    exit 1
fi
echo "  ✓ Bundle Identifier: $BUNDLE_ID"

# 4. Verify Architecture (arm64 Apple Silicon)
ARCH_INFO=$(file "$APP_PATH/Contents/MacOS/ClipBo")
if [[ "$ARCH_INFO" != *"arm64"* ]]; then
    echo "❌ Error: $APP_PATH executable is not built for arm64."
    echo "  file output: $ARCH_INFO"
    exit 1
fi
echo "  ✓ Target Architecture: arm64 (Apple Silicon)"

# 5. Extract Version
VERSION=$(defaults read "$REPO_ROOT/$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.6.4")
echo "  ✓ App Version: v$VERSION"
echo "  ✓ AppIcon verified: $APP_PATH/Contents/Resources/AppIcon.icns"

# 6. Verify Code Signature
echo "🔐 Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  ✓ Code signature verified (ad-hoc / local developer signature)"

# 7. Prepare Staging Directory
mkdir -p "$DIST_DIR"
FINAL_DMG="$DIST_DIR/ClipBo.dmg"
VERSIONED_DMG="$DIST_DIR/ClipBo-$VERSION.dmg"
TEMP_DMG="$DIST_DIR/ClipBo_temp.dmg"

# Clean previous DMGs
rm -f "$FINAL_DMG" "$VERSIONED_DMG" "$TEMP_DMG"

STAGE_DIR=$(mktemp -d -t clipbo_stage_XXXXXX)
MOUNT_DIR=$(mktemp -d -t clipbo_mnt_XXXXXX)

cleanup() {
    if mount | grep -q "$MOUNT_DIR"; then
        hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
    fi
    rm -rf "$STAGE_DIR" "$MOUNT_DIR" "$TEMP_DMG" 2>/dev/null || true
}
trap cleanup EXIT

echo "📦 Preparing DMG staging volume..."
cp -R "$APP_PATH" "$STAGE_DIR/ClipBo.app"
ln -s /Applications "$STAGE_DIR/Applications"

# Copy volume icon if available
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$STAGE_DIR/.VolumeIcon.icns"
fi

# 8. Create temporary read/write disk image
echo "🔨 Creating disk image..."
hdiutil create \
    -srcfolder "$STAGE_DIR" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 150m \
    "$TEMP_DMG" >/dev/null

# 9. Mount and configure Finder window layout
echo "🎨 Configuring drag-to-install Finder layout (720x420)..."
ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$TEMP_DMG")
DEVICE=$(echo "$ATTACH_OUTPUT" | awk 'NR==1{print $1}')

# Enable custom volume icon if SetFile exists
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && command -v SetFile &>/dev/null; then
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# Apply AppleScript Finder layout if GUI Finder is running
if [ -z "$CI" ] && pgrep -x "Finder" >/dev/null; then
    osascript << EOF 2>/dev/null || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 150, 1020, 570}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 112
        set text size of viewOptions to 12
        set arrangement of viewOptions to not arranged
        set position of item "ClipBo.app" of container window to {180, 200}
        set position of item "Applications" of container window to {540, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
fi

# Sync and unmount
sync
hdiutil detach "$DEVICE" -force >/dev/null

# 10. Convert to compressed read-only DMG (UDZO)
echo "🗜️  Compressing DMG release artifact..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG" >/dev/null

# Create versioned copy
cp "$FINAL_DMG" "$VERSIONED_DMG"

# 11. Final verification
if [ ! -f "$FINAL_DMG" ]; then
    echo "❌ Error: Failed to create $FINAL_DMG"
    exit 1
fi

DMG_SIZE=$(du -h "$FINAL_DMG" | awk '{print $1}')

echo "========================================"
echo " ✅ ClipBo DMG Created Successfully!"
echo "========================================"
echo "  Artifact: $FINAL_DMG ($DMG_SIZE)"
echo "  Version:  $VERSIONED_DMG"
echo "  Install:  Double-click to open -> Drag ClipBo.app to Applications"
echo "========================================"

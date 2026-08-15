#!/bin/bash
set -e

echo "🔨 Building ClipBo in release mode..."
swift build -c release --product ClipBoApp

APP_DIR="build/ClipBo.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "📦 Assembling $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

BIN_PATH=$(swift build -c release --show-bin-path)/ClipBoApp
cp "$BIN_PATH" "$MACOS_DIR/ClipBo"

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipBo</string>
    <key>CFBundleIdentifier</key>
    <string>com.clipbo.app</string>
    <key>CFBundleName</key>
    <string>ClipBo</string>
    <key>CFBundleDisplayName</key>
    <string>ClipBo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✍️  Ad-hoc codesigning $APP_DIR..."
codesign --force --deep --sign - "$APP_DIR"

echo "✅ ClipBo.app built successfully at: $APP_DIR"

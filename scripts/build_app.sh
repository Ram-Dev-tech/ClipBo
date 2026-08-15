#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

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

# 1. Ensure AppIcon.icns exists
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "🎨 AppIcon.icns not found. Generating macOS AppIcon assets..."
    swift scripts/generate_icon.swift
fi

# 2. Copy AppIcon into Resources
cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# 3. Create Info.plist with AppIcon configuration
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
    <string>0.6.4</string>
    <key>CFBundleVersion</key>
    <string>0.6.4</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>ClipBo uses Accessibility to quickly capture selected text and images when you trigger Quick Capture or Selection Capture.</string>
</dict>
</plist>
EOF

echo "✍️  Ad-hoc codesigning $APP_DIR with persistent identifier..."
codesign --force --deep --sign - --identifier "com.clipbo.app" "$APP_DIR"

echo "✅ ClipBo.app built successfully at: $APP_DIR"

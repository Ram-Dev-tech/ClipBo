# ClipBo

> Native macOS Clipboard Manager with Spotlight-Style Overlay & Background Selection Capture.

**ClipBo** is a private, native macOS clipboard manager built with Swift and SwiftUI for macOS 14+.

## Features
- **Spotlight-Style Quick Overlay**: Floating panel with search, arrow navigation, and circular category filters.
- **Menu Bar Panel**: Native menu bar popup with quick access to recent clips, favorites, and 3-column image gallery.
- **Background Quick Capture**:
  - **Manual Capture**: Global hotkey (`⌥⌘C`) to capture current selection without modifying `NSPasteboard`.
  - **Command + Selection Capture**: Hold `⌘` (or configured modifier) while selecting text/images to automatically save clips into history.
- **Smart Content Classification**: Automatic categorization into Text, Code, Prompt, URL, Emoji, and Images.
- **Per-Category Display Limits**: High performance UI with 30 clips displayed in "All" and 20 per individual category.
- **Native Drag-and-Drop**: AppKit drag provider supporting text, URLs, and real image thumbnail previews.
- **Privacy & Security**: Zero cloud dependencies, offline SQLite storage, and sandboxed clipboard monitoring.

## Development & Testing
```bash
# Run unit and integration tests
swift run ClipBoTests

# Build production app
./scripts/build_app.sh

# Continuous Git Sync
./scripts/git_auto_sync.sh start
./scripts/git_auto_sync.sh status
./scripts/git_auto_sync.sh stop
./scripts/git_sync_now.sh
```

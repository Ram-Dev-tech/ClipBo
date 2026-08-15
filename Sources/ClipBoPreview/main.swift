import Cocoa
import SwiftUI
import ClipBo

let app = NSApplication.shared

@MainActor
func renderPreviews() async {
    print("🎨 Generating visual UI preview snapshots...")

    let previewDir = URL(fileURLWithPath: "build/previews", isDirectory: true)
    try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)

    // 1. Setup in-memory repository with realistic sample data
    let repo = try! CoreDataClipRepository(inMemory: true)
    let tempImgDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempImgDir, withIntermediateDirectories: true)
    let imgStorage = ImageStorage(baseDirectory: tempImgDir)

    // Create 3 sample images
    var sampleImagesData: [Data] = []
    for i in 1...3 {
        let size = NSSize(width: 200, height: 150)
        let img = NSImage(size: size)
        img.lockFocus()
        if i == 1 {
            NSColor.systemBlue.drawSwatch(in: NSRect(origin: .zero, size: size))
        } else if i == 2 {
            NSColor.systemPurple.drawSwatch(in: NSRect(origin: .zero, size: size))
        } else {
            NSColor.systemTeal.drawSwatch(in: NSRect(origin: .zero, size: size))
        }
        img.unlockFocus()
        if let tiff = img.tiffRepresentation {
            sampleImagesData.append(tiff)
        }
    }
    let coordinator = AppCoordinator(repository: repo, imageStorage: imgStorage)

    // Ingest sample clips through coordinator for realistic classification
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "Act as a Python expert and explain how asyncio event loops manage non-blocking concurrency.",
        sourceAppBundleId: "com.apple.Safari",
        sourceAppName: "ChatGPT"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "Write a Swift function that implements binary search over a sorted collection.",
        sourceAppBundleId: "com.apple.dt.Xcode",
        sourceAppName: "Xcode"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "import SwiftUI\n\nfunc setupSpotlightOverlay() {\n    panel.level = .floating\n}",
        sourceAppBundleId: "com.apple.dt.Xcode",
        sourceAppName: "Xcode"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "https://github.com/apple/swift",
        sourceAppBundleId: "com.apple.Safari",
        sourceAppName: "Safari"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "#FF5733",
        sourceAppBundleId: "com.adobe.Photoshop",
        sourceAppName: "Photoshop"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "git commit -m \"feat: implement Phase 7 Universal Smart Search and Prompt classification\"",
        sourceAppBundleId: "com.apple.Terminal",
        sourceAppName: "Terminal"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "Meeting notes: Polish Spotlight quick overlay with spring transitions and circular focus pill.",
        sourceAppBundleId: "com.apple.Notes",
        sourceAppName: "Notes"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "🚀🔥🎉",
        sourceAppBundleId: "com.apple.MobileSMS",
        sourceAppName: "Messages"
    ))
    await coordinator.handleNewPayload(PasteboardPayload.text(
        "👨‍💻✨",
        sourceAppBundleId: "com.tinyspeck.slackmacgap",
        sourceAppName: "Slack"
    ))

    for (idx, imgData) in sampleImagesData.enumerated() {
        await coordinator.handleNewPayload(PasteboardPayload.image(
            data: imgData,
            width: 200,
            height: 150,
            sourceAppBundleId: "com.adobe.Photoshop",
            sourceAppName: "Photoshop (Sample \(idx + 1))"
        ))
    }

    // Star a couple of items
    if let first = coordinator.recentClips.first {
        await coordinator.toggleStar(for: first)
    }

    // 2. Render Menu Bar Panel (Light & Dark)
    let menuBarView = MenuBarPanelView(coordinator: coordinator)
    renderViewToPNG(
        view: menuBarView,
        size: NSSize(width: DesignTokens.Dimensions.menuBarWidth, height: DesignTokens.Dimensions.menuBarHeight),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("menu_bar_panel_dark.png")
    )
    renderViewToPNG(
        view: menuBarView,
        size: NSSize(width: DesignTokens.Dimensions.menuBarWidth, height: DesignTokens.Dimensions.menuBarHeight),
        appearance: .aqua,
        outputURL: previewDir.appendingPathComponent("menu_bar_panel_light.png")
    )

    // 2b. Render 3-Column Image Gallery
    let imageClips = coordinator.filteredClips(category: .images)
    let galleryView = MenuBarImageGallery(
        clips: imageClips,
        imageStorage: coordinator.imageStorage,
        onRestore: { _ in },
        onToggleStar: { _ in }
    )
    renderViewToPNG(
        view: galleryView,
        size: NSSize(width: DesignTokens.Dimensions.menuBarWidth, height: 280),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("menu_bar_gallery_dark.png")
    )

    // 3. Render Spotlight Quick Overlay Snapshots

    // A. Normal Quick Overlay (Search state)
    let overlaySearch = QuickOverlayView(coordinator: coordinator, initialState: .search, initialCategory: .all, onDismiss: {})
    renderViewToPNG(
        view: overlaySearch,
        size: NSSize(width: 600, height: 380),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_search.png")
    )
    renderViewToPNG(
        view: overlaySearch,
        size: NSSize(width: 600, height: 380),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_dark.png")
    )
    renderViewToPNG(
        view: overlaySearch,
        size: NSSize(width: 600, height: 380),
        appearance: .aqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_light.png")
    )

    // B. Quick Overlay with Categories Row Revealed
    let overlayCategories = QuickOverlayView(coordinator: coordinator, initialState: .categories, initialCategory: .all, onDismiss: {})
    renderViewToPNG(
        view: overlayCategories,
        size: NSSize(width: 600, height: 380),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_categories.png")
    )

    // C. Quick Overlay with Category Selected (Code)
    let overlayCategorySelected = QuickOverlayView(coordinator: coordinator, initialState: .categories, initialCategory: .code, onDismiss: {})
    renderViewToPNG(
        view: overlayCategorySelected,
        size: NSSize(width: 600, height: 380),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_category_selected.png")
    )

    // D. Quick Overlay Filtered by Prompt
    let overlayPrompt = QuickOverlayView(coordinator: coordinator, initialState: .search, initialCategory: .prompt, onDismiss: {})
    renderViewToPNG(
        view: overlayPrompt,
        size: NSSize(width: 600, height: 380),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_prompt.png")
    )

    // E. Quick Overlay Filtered by Emoji
    let overlayEmoji = QuickOverlayView(coordinator: coordinator, initialState: .search, initialCategory: .emoji, onDismiss: {})
    renderViewToPNG(
        view: overlayEmoji,
        size: NSSize(width: 600, height: 380),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_emoji.png")
    )

    // F. Min and Large Bounds
    let overlayMin = QuickOverlayView(coordinator: coordinator, initialState: .categories, initialCategory: .all, onDismiss: {})
    renderViewToPNG(
        view: overlayMin,
        size: NSSize(width: 520, height: 300),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_min.png")
    )
    let overlayLarge = QuickOverlayView(coordinator: coordinator, initialState: .categories, initialCategory: .all, onDismiss: {})
    renderViewToPNG(
        view: overlayLarge,
        size: NSSize(width: 800, height: 500),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("quick_overlay_large.png")
    )

    // 4. Render Category Settings View with ✦ Prompt
    let categorySettingsView = CategorySettingsView(settingsService: coordinator.settingsService)
        .padding(20)
        .frame(width: 480)
    renderViewToPNG(
        view: categorySettingsView,
        size: NSSize(width: 480, height: 440),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("category_settings_dark.png")
    )

    // 4b. Render Storage Settings View
    let storageSettingsView = StorageSettingsView(
        clipCount: 30,
        starredCount: 4,
        imageCount: 3,
        databaseSizeBytes: 122880,
        sqliteSizeBytes: 81920,
        walSizeBytes: 40960,
        imagesSizeBytes: 1843200,
        onClearHistory: {},
        onClearImages: {}
    )
    .padding(20)
    .frame(width: 480)
    renderViewToPNG(
        view: storageSettingsView,
        size: NSSize(width: 480, height: 440),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("storage_settings_dark.png")
    )

    // 4c. Render Help Settings View
    let helpSettingsView = HelpSettingsView(settingsService: coordinator.settingsService)
        .padding(20)
        .frame(width: 480)
    renderViewToPNG(
        view: helpSettingsView,
        size: NSSize(width: 480, height: 500),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("help_settings_dark.png")
    )

    // 5. Render Settings (Light & Dark)
    let settingsView = SettingsView(settingsService: coordinator.settingsService, coordinator: coordinator)
    renderViewToPNG(
        view: settingsView,
        size: NSSize(width: 560, height: 520),
        appearance: .darkAqua,
        outputURL: previewDir.appendingPathComponent("settings_dark.png")
    )
    renderViewToPNG(
        view: settingsView,
        size: NSSize(width: 560, height: 520),
        appearance: .aqua,
        outputURL: previewDir.appendingPathComponent("settings_light.png")
    )

    print("✅ All previews rendered successfully to build/previews/")
    exit(0)
}

@MainActor
func renderViewToPNG<V: View>(view: V, size: NSSize, appearance: NSAppearance.Name, outputURL: URL) {
    let controller = NSHostingController(rootView: view)
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: appearance)
    window.contentViewController = controller
    window.setContentSize(size)
    window.layoutIfNeeded()

    let view = controller.view
    view.frame = NSRect(origin: .zero, size: size)
    view.layoutSubtreeIfNeeded()

    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: outputURL)
        print("  📸 Saved: \(outputURL.lastPathComponent)")
    }
}

// Run on main runloop
Task { @MainActor in
    await renderPreviews()
}

app.run()

import Cocoa
import SwiftUI
import ClipBo

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
    let coordinator = AppCoordinator(repository: repo, imageStorage: imgStorage)

    // Create 3 sample images
    var sampleImageNames: [String] = []
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
        if let tiff = img.tiffRepresentation, let name = try? imgStorage.saveImage(data: tiff) {
            sampleImageNames.append(name)
        }
    }

    // Insert sample clips
    let sampleClips = [
        Clip.text("git commit -m \"feat: implement Phase 2 dual macOS interfaces\"", sourceAppName: "Terminal"),
        Clip(id: UUID(), type: .code, textContent: "func setupSpotlightOverlay() {\n    panel.level = .floating\n}", createdAt: Date().addingTimeInterval(-180), isStarred: true, sourceAppName: "Xcode"),
        Clip.url("https://developer.apple.com/design/human-interface-guidelines", sourceAppName: "Safari"),
        Clip.text("Meeting notes: Polish Spotlight quick overlay with spring transitions and circular focus pill.", createdAt: Date().addingTimeInterval(-3600), isStarred: false, sourceAppName: "Notes"),
        Clip.image(imagePath: sampleImageNames.first ?? "", width: 200, height: 150, sourceAppName: "Photoshop")
    ]

    for clip in sampleClips {
        try? await repo.insert(clip)
    }
    await coordinator.reloadRecentClips()

    // 2. Render Menu Bar Panel (Light & Dark)
    let menuBarView = MenuBarPanelView(coordinator: coordinator)
    renderViewToPNG(
        view: menuBarView,
        size: NSSize(width: DesignTokens.Dimensions.menuBarWidth, height: DesignTokens.Dimensions.menuBarHeight),
        appearance: .dark,
        outputURL: previewDir.appendingPathComponent("menu_bar_panel_dark.png")
    )
    renderViewToPNG(
        view: menuBarView,
        size: NSSize(width: DesignTokens.Dimensions.menuBarWidth, height: DesignTokens.Dimensions.menuBarHeight),
        appearance: .light,
        outputURL: previewDir.appendingPathComponent("menu_bar_panel_light.png")
    )

    // 3. Render Quick Overlay (Light & Dark)
    let quickOverlayView = QuickOverlayView(coordinator: coordinator, onDismiss: {})
    renderViewToPNG(
        view: quickOverlayView,
        size: NSSize(width: DesignTokens.Dimensions.quickOverlayWidth, height: 360),
        appearance: .dark,
        outputURL: previewDir.appendingPathComponent("quick_overlay_dark.png")
    )
    renderViewToPNG(
        view: quickOverlayView,
        size: NSSize(width: DesignTokens.Dimensions.quickOverlayWidth, height: 360),
        appearance: .light,
        outputURL: previewDir.appendingPathComponent("quick_overlay_light.png")
    )

    print("✅ Previews saved to build/previews/")
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

    guard let view = controller.view as? NSView else { return }
    view.frame = NSRect(origin: .zero, size: size)
    view.layoutSubtreeIfNeeded()

    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: outputURL)
        print("  📸 Rendered: \(outputURL.lastPathComponent)")
    }
}

// Top level execution
let sem = DispatchSemaphore(value: 0)
Task { @MainActor in
    await renderPreviews()
    sem.signal()
}
sem.wait()

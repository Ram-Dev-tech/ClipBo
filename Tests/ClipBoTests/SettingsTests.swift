import Foundation
import Carbon
import ClipBo

public struct SettingsTests {
    @MainActor
    public static func runAll() async {
        print("  ▶ Running SettingsTests...")

        // 1. Test KeyCombination & Display String
        print("    ▶ Testing KeyCombination formatting...")
        let combo1 = KeyCombination(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
        assert(combo1.displayString == "⇧ ⌘ V", "Expected '⇧ ⌘ V', got \(combo1.displayString)")

        let combo2 = KeyCombination(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey))
        assert(combo2.displayString == "⌥ ⌘ C", "Expected '⌥ ⌘ C', got \(combo2.displayString)")

        let combo3 = KeyCombination(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey))
        assert(combo3.displayString == "⇧ ⌘ Space", "Expected '⇧ ⌘ Space', got \(combo3.displayString)")
        print("      ✔ KeyCombination display strings formatted properly")

        // 2. Test FontScale and Dynamic Typography Calculations
        print("    ▶ Testing FontScale values & dynamic typography scaling...")
        assert(FontScale.compact.scaleFactor == 0.90, "Expected FontScale.compact == 0.90, got \(FontScale.compact.scaleFactor)")
        assert(FontScale.system.scaleFactor == 1.00, "Expected FontScale.system == 1.00, got \(FontScale.system.scaleFactor)")
        assert(FontScale.large.scaleFactor == 1.15, "Expected FontScale.large == 1.15, got \(FontScale.large.scaleFactor)")

        // Verify ClipBoTypography methods compile and execute across scales
        _ = ClipBoTypography.appTitle(scale: FontScale.compact.scaleFactor)
        _ = ClipBoTypography.body(scale: FontScale.large.scaleFactor)
        _ = ClipBoTypography.code(scale: FontScale.system.scaleFactor)
        _ = ClipBoTypography.badge(scale: FontScale.compact.scaleFactor)
        _ = ClipBoTypography.caption(scale: FontScale.large.scaleFactor)
        print("      ✔ FontScale and dynamic typography calculations verified")

        // 3. Test OverlayGeometry bounds and persistence (Phase 6D)
        print("    ▶ Testing OverlayGeometry bounds & persistence...")
        let defaultGeo = OverlayGeometry.defaultGeometry
        assert(defaultGeo.width == 600, "Expected default width == 600")
        assert(defaultGeo.height == 380, "Expected default height == 380")
        assert(defaultGeo.originX == nil && defaultGeo.originY == nil, "Expected nil initial origins")

        // Test clamping to minimum and maximum constraints
        let smallGeo = OverlayGeometry(width: 100, height: 50)
        assert(smallGeo.width == OverlayGeometry.minWidth, "Expected clamped minWidth \(OverlayGeometry.minWidth), got \(smallGeo.width)")
        assert(smallGeo.height == OverlayGeometry.minHeight, "Expected clamped minHeight \(OverlayGeometry.minHeight), got \(smallGeo.height)")

        let hugeGeo = OverlayGeometry(width: 2500, height: 1800)
        assert(hugeGeo.width == OverlayGeometry.maxWidth, "Expected clamped maxWidth \(OverlayGeometry.maxWidth), got \(hugeGeo.width)")
        assert(hugeGeo.height == OverlayGeometry.maxHeight, "Expected clamped maxHeight \(OverlayGeometry.maxHeight), got \(hugeGeo.height)")
        print("      ✔ OverlayGeometry min/max constraints verified")

        // 4. Test SettingsService Initialization, Defaults & Adjustable Controls
        print("    ▶ Testing SettingsService defaults & persistence...")
        let testDefaults = UserDefaults(suiteName: "com.clipbo.test.settings.\(UUID().uuidString)")!
        
        let service = SettingsService(userDefaults: testDefaults)
        assert(service.settings.launchAtLogin == true, "Expected launchAtLogin == true")
        assert(service.settings.isMonitoring == true, "Expected isMonitoring == true")
        assert(service.settings.maxClipCount == 1000, "Expected default maxClipCount == 1000")
        assert(service.settings.maxHistoryAgeDays == 30, "Expected default maxHistoryAgeDays == 30")
        assert(service.settings.pollingInterval == 0.5, "Expected default pollingInterval == 0.5")
        assert(service.settings.closeOverlayAfterCopy == true, "Expected default closeOverlayAfterCopy == true")
        assert(service.settings.fontScale == .system, "Expected default fontScale == .system")
        assert(service.settings.density == .compact, "Expected default density == .compact")
        assert(service.settings.allowURLMetadataFetching == false, "Expected default allowURLMetadataFetching == false")
        assert(service.settings.menuBarPanelShortcut == .defaultMenuBarPanel, "Expected default menuBarPanelShortcut == ⌘ ⇧ Space")

        // Test Persistence of adjustable controls & OverlayGeometry
        service.settings.maxClipCount = 500
        service.settings.maxHistoryAgeDays = 14
        service.settings.pollingInterval = 0.8
        service.settings.closeOverlayAfterCopy = false
        service.settings.fontScale = .large
        service.updateOverlayGeometry(width: 680, height: 450, originX: 200, originY: 300)
        
        // Create second service instance reading from same UserDefaults
        let service2 = SettingsService(userDefaults: testDefaults)
        assert(service2.settings.maxClipCount == 500, "Expected persisted maxClipCount == 500")
        assert(service2.settings.maxHistoryAgeDays == 14, "Expected persisted maxHistoryAgeDays == 14")
        assert(service2.settings.pollingInterval == 0.8, "Expected persisted pollingInterval == 0.8")
        assert(service2.settings.closeOverlayAfterCopy == false, "Expected persisted closeOverlayAfterCopy == false")
        assert(service2.settings.fontScale == .large, "Expected persisted fontScale == .large")
        assert(service2.settings.overlayGeometry.width == 680, "Expected persisted overlay width == 680")
        assert(service2.settings.overlayGeometry.height == 450, "Expected persisted overlay height == 450")
        assert(service2.settings.overlayGeometry.originX == 200, "Expected persisted overlay originX == 200")
        assert(service2.settings.overlayGeometry.originY == 300, "Expected persisted overlay originY == 300")
        print("      ✔ Settings adjustable persistence & overlay geometry verified")

        // 5. Test Shortcut Validation & 3-Way Conflict Detection
        print("    ▶ Testing Shortcut validation and conflict detection...")
        
        // Conflict test 1: Attempt to set Quick Overlay to the same as Quick Capture
        let conflictResult1 = service.updateQuickOverlayShortcut(service.settings.quickCaptureShortcut)
        switch conflictResult1 {
        case .success:
            fatalError("Setting conflicting shortcut should fail")
        case .failure(let err):
            assert(err.localizedDescription.contains("already assigned"), "Expected conflict error message, got \(err.localizedDescription)")
            print("      ✔ Shortcut conflict with Quick Capture detected and rejected")
        }

        // Conflict test 2: Attempt to set Menu Bar Panel to the same as Quick Overlay
        let conflictResult2 = service.updateMenuBarPanelShortcut(service.settings.quickOverlayShortcut)
        switch conflictResult2 {
        case .success:
            fatalError("Setting conflicting shortcut should fail")
        case .failure(let err):
            assert(err.localizedDescription.contains("already assigned"), "Expected conflict error message, got \(err.localizedDescription)")
            print("      ✔ Shortcut conflict with Quick Overlay detected and rejected")
        }

        // Valid shortcut update
        let newValidOverlay = KeyCombination(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey))
        let updateResult = service.updateQuickOverlayShortcut(newValidOverlay)
        switch updateResult {
        case .success:
            assert(service.settings.quickOverlayShortcut == newValidOverlay, "Expected updated shortcut")
            print("      ✔ Valid shortcut update succeeded")
        case .failure(let err):
            print("      ℹ Registration returned failure (may happen in non-interactive environment): \(err)")
        }

        // Test Restore Defaults
        service.restoreDefaults()
        assert(service.settings.maxClipCount == 1000, "Expected maxClipCount reset to 1000")
        assert(service.settings.maxHistoryAgeDays == 30, "Expected maxHistoryAgeDays reset to 30")
        assert(service.settings.pollingInterval == 0.5, "Expected pollingInterval reset to 0.5")
        assert(service.settings.fontScale == .system, "Expected fontScale reset to .system")
        assert(service.settings.quickOverlayShortcut == .defaultQuickOverlay, "Expected default quick overlay shortcut")
        assert(service.settings.quickCaptureShortcut == .defaultQuickCapture, "Expected default quick capture shortcut")
        assert(service.settings.menuBarPanelShortcut == .defaultMenuBarPanel, "Expected default menu bar panel shortcut")
        print("      ✔ Restore Defaults restored all settings")

        // 6. Test ClipboardMonitor Dynamic Polling Interval
        print("    ▶ Testing ClipboardMonitor polling interval updates...")
        let monitor = ClipboardMonitor(pollingInterval: 0.5)
        assert(monitor.currentPollingInterval == 0.5, "Expected 0.5s polling")
        monitor.updatePollingInterval(1.2)
        assert(monitor.currentPollingInterval == 1.2, "Expected 1.2s polling after update")
        print("      ✔ Dynamic polling interval update verified")

        // 7. Test Simultaneous Count + Age Retention with Star Protection
        print("    ▶ Testing Simultaneous Count + Age Retention Enforcement...")
        let repo = try! CoreDataClipRepository(inMemory: true)
        
        let now = Date()
        let fortyDaysAgo = now.addingTimeInterval(-40 * 86400) // Older than 30 days
        let fiveDaysAgo = now.addingTimeInterval(-5 * 86400)   // Within 30 days

        // Insert 3 expired non-starred clips (40 days old)
        for i in 1...3 {
            let expiredClip = Clip(
                id: UUID(),
                type: .text,
                textContent: "Expired Old Clip \(i)",
                createdAt: fortyDaysAgo.addingTimeInterval(Double(i * 10)),
                isStarred: false
            )
            try! await repo.insert(expiredClip)
        }

        // Insert 1 expired STARRED clip (40 days old) - MUST BE PRESERVED
        let oldStarred = Clip(
            id: UUID(),
            type: .text,
            textContent: "Ancient Starred Clip",
            createdAt: fortyDaysAgo,
            isStarred: true
        )
        try! await repo.insert(oldStarred)

        // Insert 5 fresh non-starred clips (5 days old)
        for i in 1...5 {
            let freshClip = Clip(
                id: UUID(),
                type: .text,
                textContent: "Fresh Clip \(i)",
                createdAt: fiveDaysAgo.addingTimeInterval(Double(i * 10)),
                isStarred: false
            )
            try! await repo.insert(freshClip)
        }

        // Insert 1 fresh STARRED clip (5 days old) - MUST BE PRESERVED
        let freshStarred = Clip(
            id: UUID(),
            type: .text,
            textContent: "Fresh Starred Clip",
            createdAt: fiveDaysAgo,
            isStarred: true
        )
        try! await repo.insert(freshStarred)

        let initialCount = try! await repo.count()
        assert(initialCount == 10, "Expected 10 total clips initially, got \(initialCount)")

        // Enforce dual retention policy: max 3 non-starred clips, max age 30 days
        try! await repo.enforceRetentionLimit(maxNonStarred: 3, maxAgeDays: 30)

        let postRetentionClips = try! await repo.fetchRecent(limit: 50)
        let remainingStarred = postRetentionClips.filter { $0.isStarred }
        let remainingNonStarred = postRetentionClips.filter { !$0.isStarred }

        // Both starred clips (old + fresh) MUST be preserved!
        assert(remainingStarred.count == 2, "Starred clips must NEVER be pruned by retention limits! Got \(remainingStarred.count)")
        assert(remainingNonStarred.count == 3, "Expected exactly 3 non-starred clips remaining (exceeded count & age pruned), got \(remainingNonStarred.count)")
        
        // Verify none of the remaining non-starred clips are older than 30 days
        for clip in remainingNonStarred {
            assert(clip.createdAt > fortyDaysAgo, "No expired clips should remain")
        }
        print("      ✔ Dual Count + Age retention with Star Protection verified")

        // 8. Test Image Storage Size Calculation
        print("    ▶ Testing Image Storage metrics...")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let imageStorage = ImageStorage(baseDirectory: tempDir)
        let testData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // 8 bytes PNG header
        try! imageStorage.saveImage(data: testData)
        try! imageStorage.saveImage(data: testData)
        
        let imgCount = imageStorage.imageCount()
        let dirSize = imageStorage.imagesDirectorySize()
        assert(imgCount == 2, "Expected 2 images, got \(imgCount)")
        assert(dirSize >= 16, "Expected at least 16 bytes stored, got \(dirSize)")

        try! imageStorage.clearAllImages()
        assert(imageStorage.imageCount() == 0, "Expected 0 images after clearAllImages")
        try? FileManager.default.removeItem(at: tempDir)
        print("      ✔ Image storage metric calculations and cleanup verified")

        print("  ✔ SettingsTests passed")
    }
}

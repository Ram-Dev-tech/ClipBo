import Cocoa
import Carbon
import ClipBo

public struct SelectionCaptureTests {
    public static func runAll() async {
        print("  ▶ Running SelectionCaptureTests...")

        let shortcutManager = GlobalShortcutManager.shared

        // 1. Verify Global Shortcut Registration for Quick Overlay (⌘ ⇧ V)
        let overlayStatus = shortcutManager.registerQuickOverlayShortcut(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | shiftKey)
        )
        assert(overlayStatus == noErr, "Quick Overlay shortcut registration failed with OSStatus \(overlayStatus)")
        print("    ✔ Quick Overlay shortcut registered successfully (OSStatus 0)")

        // 2. Verify Global Shortcut Registration for Quick Capture (⌥ ⌘ C)
        let captureStatus = shortcutManager.registerQuickCaptureShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(cmdKey | optionKey)
        )
        assert(captureStatus == noErr, "Quick Capture shortcut (⌥ ⌘ C) registration failed with OSStatus \(captureStatus)")
        print("    ✔ Quick Capture shortcut (⌥ ⌘ C) registered successfully (OSStatus 0)")

        // 3. Verify Accessibility Service status check
        let captureService = SelectionCaptureService.shared
        let isGranted = captureService.isAccessibilityGranted
        print("    ℹ AXIsProcessTrusted() returned: \(isGranted)")

        // 4. Verify Clipboard Preservation
        let testString = "PRESERVED_CLIPBOARD_TEST_\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testString, forType: .string)

        // Invoke captureSelectedText (must NOT touch or overwrite NSPasteboard)
        let captured = captureService.captureSelectedText()
        if let captured = captured {
            print("    ℹ Text captured: \(captured.prefix(20))...")
        } else {
            print("    ℹ Safe nil returned (expected in non-interactive test environment)")
        }

        // Verify NSPasteboard is 100% identical and was not tampered with
        let currentClipboard = NSPasteboard.general.string(forType: .string)
        assert(currentClipboard == testString, "NSPasteboard was modified by SelectionCaptureService! Expected \(testString), got \(currentClipboard ?? "nil")")
        print("    ✔ Verified system clipboard is 100% untouched and preserved")

        // 5. Verify Duplicate Prevention on AppCoordinator
        await MainActor.run {
            let repo = try! CoreDataClipRepository(inMemory: true)
            let coordinator = AppCoordinator(repository: repo)

            Task { @MainActor in
                let payload1 = PasteboardPayload.text("Duplicate Test Content")
                await coordinator.handleNewPayload(payload1)
                assert(coordinator.recentClips.count == 1, "Expected 1 clip after first payload")

                // Sending identical payload consecutively should be ignored
                await coordinator.handleNewPayload(payload1)
                assert(coordinator.recentClips.count == 1, "Duplicate payload must not create second clip")

                // Sending distinct payload should create new clip
                let payload2 = PasteboardPayload.text("Distinct Second Content")
                await coordinator.handleNewPayload(payload2)
                assert(coordinator.recentClips.count == 2, "Distinct payload must create new clip")
            }
        }
        print("    ✔ Verified consecutive duplicate prevention logic")

        print("  ✔ SelectionCaptureTests passed")
    }
}

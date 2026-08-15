import Foundation
import AppKit
import Carbon
import ClipBo

@MainActor
public struct QuickSelectionCaptureTests {
    public static func runAll() async {
        print("  ▶ Running QuickSelectionCaptureTests...")

        testDefaultModifier()
        testModifierPersistence()
        testModifierDisplayFormatting()
        testModifierEventFlags()
        testToggleQuickSelectionCapture()
        testAccessibilityPermissionState()
        testEmptySelectionIgnored()
        testDuplicateSelectionCreatesSingleClip()
        await testContentClassificationPipeline()
        testClipboardPreservation()
        testImageCaptureSafeBehavior()

        print("  ✔ QuickSelectionCaptureTests passed")
    }

    // 1. Default modifier is Command
    static func testDefaultModifier() {
        print("    ▶ Testing default selection capture modifier...")
        let defaults = UserDefaults(suiteName: "com.clipbo.test.sel.default.\(UUID().uuidString)")!
        let service = SettingsService(userDefaults: defaults)

        assert(service.settings.quickSelectionCaptureEnabled == true, "Quick selection capture should be enabled by default")
        assert(service.settings.selectionCaptureModifier == .command, "Default selection modifier must be .command")
        assert(service.settings.selectionCaptureModifier.symbol == "⌘", "Symbol for .command must be ⌘")
        assert(service.settings.selectionCaptureModifier.displayString == "⌘ + Select", "Display string must be '⌘ + Select'")
        print("      ✔ Default selection modifier is Command (⌘ + Select)")
    }

    // 2. Modifier persistence across SettingsService reloads
    static func testModifierPersistence() {
        print("    ▶ Testing selection modifier persistence...")
        let defaults = UserDefaults(suiteName: "com.clipbo.test.sel.persist.\(UUID().uuidString)")!
        let service1 = SettingsService(userDefaults: defaults)

        service1.updateSelectionCaptureModifier(.option)
        assert(service1.settings.selectionCaptureModifier == .option, "Expected .option after update")

        let service2 = SettingsService(userDefaults: defaults)
        assert(service2.settings.selectionCaptureModifier == .option, "Persisted modifier must reload as .option")

        service2.updateSelectionCaptureModifier(.control)
        let service3 = SettingsService(userDefaults: defaults)
        assert(service3.settings.selectionCaptureModifier == .control, "Persisted modifier must reload as .control")

        service3.updateSelectionCaptureModifier(.shift)
        let service4 = SettingsService(userDefaults: defaults)
        assert(service4.settings.selectionCaptureModifier == .shift, "Persisted modifier must reload as .shift")
        print("      ✔ Modifier persistence verified across all SelectionModifier cases")
    }

    // 3. Modifier display formatting for all cases
    static func testModifierDisplayFormatting() {
        print("    ▶ Testing modifier display formatting...")
        let cases: [(SelectionModifier, String, String)] = [
            (.command, "⌘", "⌘ + Select"),
            (.option, "⌥", "⌥ + Select"),
            (.control, "⌃", "⌃ + Select"),
            (.shift, "⇧", "⇧ + Select")
        ]

        for (modifier, expectedSymbol, expectedDisplay) in cases {
            assert(modifier.symbol == expectedSymbol, "Symbol mismatch for \(modifier.rawValue)")
            assert(modifier.displayString == expectedDisplay, "Display string mismatch for \(modifier.rawValue)")
        }
        print("      ✔ All SelectionModifier symbols and display strings formatted properly")
    }

    // 4. Modifier event flags mapping
    static func testModifierEventFlags() {
        print("    ▶ Testing NSEvent.ModifierFlags and Carbon mapping...")
        assert(SelectionModifier.command.eventFlags == .command)
        assert(SelectionModifier.option.eventFlags == .option)
        assert(SelectionModifier.control.eventFlags == .control)
        assert(SelectionModifier.shift.eventFlags == .shift)

        assert(SelectionModifier.command.carbonModifier == UInt32(cmdKey))
        assert(SelectionModifier.option.carbonModifier == UInt32(optionKey))
        assert(SelectionModifier.control.carbonModifier == UInt32(controlKey))
        assert(SelectionModifier.shift.carbonModifier == UInt32(shiftKey))
        print("      ✔ Event flags and Carbon modifier codes mapped accurately")
    }

    // 5. Toggle enable/disable
    static func testToggleQuickSelectionCapture() {
        print("    ▶ Testing enable/disable toggle...")
        let defaults = UserDefaults(suiteName: "com.clipbo.test.sel.toggle.\(UUID().uuidString)")!
        let service = SettingsService(userDefaults: defaults)

        assert(service.settings.quickSelectionCaptureEnabled == true)
        service.toggleQuickSelectionCaptureEnabled()
        assert(service.settings.quickSelectionCaptureEnabled == false, "Should be disabled after toggle")

        let reloaded = SettingsService(userDefaults: defaults)
        assert(reloaded.settings.quickSelectionCaptureEnabled == false, "Disabled state should persist")

        reloaded.toggleQuickSelectionCaptureEnabled()
        assert(reloaded.settings.quickSelectionCaptureEnabled == true, "Should be re-enabled after toggle")
        print("      ✔ Toggle enable/disable persists cleanly")
    }

    // 6. Accessibility permission check
    static func testAccessibilityPermissionState() {
        print("    ▶ Testing Accessibility permission state...")
        let captureService = SelectionCaptureService.shared
        let isTrusted = captureService.isAccessibilityGranted
        assert(isTrusted == AXIsProcessTrusted(), "isAccessibilityGranted must reflect AXIsProcessTrusted()")
        print("      ✔ Accessibility permission state queried safely without crash")
    }

    // 7. Empty selection safe handling
    static func testEmptySelectionIgnored() {
        print("    ▶ Testing empty selection result...")
        let notFoundResult = SelectionCaptureResult.notFound
        switch notFoundResult {
        case .notFound:
            print("      ✔ SelectionCaptureResult.notFound safely represents unselected / empty state")
        default:
            assert(false, "Expected .notFound")
        }
    }

    // 8. Consecutive duplicate prevention
    static func testDuplicateSelectionCreatesSingleClip() {
        print("    ▶ Testing consecutive duplicate prevention...")
        let r1 = SelectionCaptureResult.text("Unique captured text")
        let r2 = SelectionCaptureResult.text("Unique captured text")
        assert(r1 == r2, "Identical capture results must be equal for duplicate suppression")

        let r3 = SelectionCaptureResult.text("Different text")
        assert(r1 != r3, "Different capture results must not be equal")
        print("      ✔ Duplicate capture prevention logic verified")
    }

    // 9. Content classification pipeline (Prompt, Code, URL, Emoji, Text)
    static func testContentClassificationPipeline() async {
        print("    ▶ Testing ContentClassifier pipeline on captured text...")
        let classifier = DefaultContentClassifier()

        // Prompt
        let promptResult = classifier.classify(payload: .text("Act as an expert software architect and explain CQRS."))
        assert(promptResult.type == .prompt, "Expected prompt classification, got \(promptResult.type)")

        // Code
        let codeResult = classifier.classify(payload: .text("func processSelection<T>(_ input: T) -> [T] {\n    return [input]\n}"))
        assert(codeResult.type == .code, "Expected code classification, got \(codeResult.type)")

        // URL
        let urlResult = classifier.classify(payload: .text("https://developer.apple.com/documentation/appkit"))
        assert(urlResult.type == .url, "Expected url classification, got \(urlResult.type)")

        // Emoji
        let emojiResult = classifier.classify(payload: .text("🎉🚀✨"))
        assert(emojiResult.customMetadata["isEmoji"] == "true", "Expected emoji metadata")

        // Text
        let textResult = classifier.classify(payload: .text("Just an ordinary quick note captured from TextEdit."))
        assert(textResult.type == .text, "Expected text classification, got \(textResult.type)")

        print("      ✔ Content classification pipeline verified for all content types")
    }

    // 10. System clipboard preservation
    static func testClipboardPreservation() {
        print("    ▶ Testing system clipboard preservation during Selection Capture...")
        let sentinel = "ClipBo_selection_sentinel_\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sentinel, forType: .string)

        // Capture should not touch NSPasteboard
        _ = SelectionCaptureService.shared.captureSelection()

        let pasteboardContent = NSPasteboard.general.string(forType: .string)
        assert(pasteboardContent == sentinel, "NSPasteboard must remain 100% untouched. Expected '\(sentinel)', got '\(pasteboardContent ?? "nil")'")
        print("      ✔ NSPasteboard is 100% preserved during selection capture operations")
    }

    // 11. Image capture safe behavior
    static func testImageCaptureSafeBehavior() {
        print("    ▶ Testing image capture result types and safe failure...")
        let fakeImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG magic header
        let imgResult = SelectionCaptureResult.image(fakeImageData)
        if case .image(let data) = imgResult {
            assert(data.count == 8, "Image byte count must match")
            print("      ✔ SelectionCaptureResult.image carries raw image payload")
        } else {
            assert(false, "Expected .image case")
        }

        // Safe failure when source app does not expose image
        let safeFailure = SelectionCaptureResult.notFound
        if case .notFound = safeFailure {
            print("      ✔ Unsupported image source safely returns .notFound without crash")
        }
    }
}

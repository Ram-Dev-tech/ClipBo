import Foundation
import AppKit
import ClipBo

public struct ClipboardWriterTests {
    public static func runAll() throws {
        print("  ▶ Running ClipboardWriterTests...")
        try testWriteTextToPasteboard()
        try testWriteURLToPasteboard()
        try testWriteImageClipToPasteboard()
        try testWriteEmptyThrows()
        try testCoordinatorRestoreReturnsBool()
        print("  ✔ ClipboardWriterTests passed")
    }

    static func testWriteTextToPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.writer.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: storage)

        try writer.writeText("Restored text", to: pasteboard)

        try assertEqual(pasteboard.string(forType: .string), "Restored text")
        try assertTrue(writer.isSelfWrite(changeCount: pasteboard.changeCount))
    }

    static func testWriteURLToPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.writer.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: storage)

        try writer.writeURL("https://developer.apple.com", to: pasteboard)

        try assertEqual(pasteboard.string(forType: .string), "https://developer.apple.com")
        try assertEqual(pasteboard.string(forType: .URL), "https://developer.apple.com")
        try assertTrue(writer.isSelfWrite(changeCount: pasteboard.changeCount))
    }

    static func testWriteImageClipToPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.writer.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let imageStorage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: imageStorage)

        let sampleImage = NSImage(size: NSSize(width: 20, height: 20))
        sampleImage.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 20, height: 20))
        sampleImage.unlockFocus()
        
        let tiff = sampleImage.tiffRepresentation!
        let filename = try imageStorage.saveImage(data: tiff)

        let clip = Clip.image(imagePath: filename, width: 20, height: 20)
        try writer.restoreClip(clip, to: pasteboard)

        try assertTrue(writer.isSelfWrite(changeCount: pasteboard.changeCount))
        try assertNotNil(pasteboard.data(forType: .tiff))
    }

    static func testWriteEmptyThrows() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.writer.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: storage)

        try assertThrows({
            try writer.writeText("", to: pasteboard)
        })
    }

    static func testCoordinatorRestoreReturnsBool() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let repo = try! CoreDataClipRepository(inMemory: true)
        
        Task { @MainActor in
            let coordinator = AppCoordinator(repository: repo, imageStorage: storage)
            
            // Valid text clip restore -> returns true
            let validClip = Clip.text("Double click copy test")
            let success = coordinator.restoreClip(validClip)
            assert(success == true, "Expected restoreClip to return true for valid text clip")

            // Empty text clip restore -> returns false gracefully
            let emptyClip = Clip(type: .text, textContent: "")
            let failure = coordinator.restoreClip(emptyClip)
            assert(failure == false, "Expected restoreClip to return false for empty clip without throwing")
        }
    }
}

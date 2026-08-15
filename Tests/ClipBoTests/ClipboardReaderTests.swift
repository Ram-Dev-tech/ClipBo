import Foundation
import AppKit
import ClipBo

public struct ClipboardReaderTests {
    public static func runAll() throws {
        print("  ▶ Running ClipboardReaderTests...")
        try testReadPlainText()
        try testReadWebURL()
        try testReadEmptyPasteboard()
        try testReadImage()
        try testIgnoreConcealedPasswordData()
        print("  ✔ ClipboardReaderTests passed")
    }

    static func testReadPlainText() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.reader.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()

        pasteboard.clearContents()
        pasteboard.setString("Hello World", forType: .string)

        let payload = reader.read(from: pasteboard)
        try assertNotNil(payload)
        try assertEqual(payload?.type, .text)
        try assertEqual(payload?.textContent, "Hello World")
    }

    static func testReadWebURL() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.reader.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()

        pasteboard.clearContents()
        pasteboard.setString("https://github.com", forType: .string)

        let payload = reader.read(from: pasteboard)
        try assertNotNil(payload)
        try assertEqual(payload?.type, .url)
        try assertEqual(payload?.textContent, "https://github.com")
    }

    static func testReadEmptyPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.reader.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()

        pasteboard.clearContents()
        let payload = reader.read(from: pasteboard)
        try assertNil(payload)
    }

    static func testReadImage() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.reader.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()

        pasteboard.clearContents()
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 10, height: 10))
        image.unlockFocus()

        pasteboard.writeObjects([image])

        let payload = reader.read(from: pasteboard)
        try assertNotNil(payload)
        try assertEqual(payload?.type, .image)
        try assertNotNil(payload?.imageData)
    }

    static func testIgnoreConcealedPasswordData() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.reader.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()

        pasteboard.clearContents()
        pasteboard.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("SuperSecretPassword123", forType: .string)

        let payload = reader.read(from: pasteboard)
        try assertNil(payload, "Should ignore concealed passwords")
    }
}

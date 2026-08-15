import Foundation
import AppKit
import ClipBo

private actor TestCaptureBox {
    var count: Int = 0
    var lastPayload: PasteboardPayload?

    func record(_ payload: PasteboardPayload) {
        count += 1
        lastPayload = payload
    }

    func getCount() -> Int { count }
    func getLastPayload() -> PasteboardPayload? { lastPayload }
}

public struct ClipboardMonitorTests {
    public static func runAll() async throws {
        print("  ▶ Running ClipboardMonitorTests...")
        try await testDetectsNewTextPayload()
        try await testIgnoresSelfWrite()
        try await testDeduplicatesConsecutiveIdenticalPayloads()
        print("  ✔ ClipboardMonitorTests passed")
    }

    static func testDetectsNewTextPayload() async throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.monitor.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: storage)
        let monitor = ClipboardMonitor(pasteboard: pasteboard, reader: reader, writer: writer, pollingInterval: 0.05)

        let box = TestCaptureBox()

        monitor.onNewPayload = { payload in
            await box.record(payload)
        }

        monitor.start()

        pasteboard.clearContents()
        pasteboard.setString("Testing Monitor", forType: .string)
        monitor.checkForChanges()

        try await Task.sleep(nanoseconds: 200_000_000)
        monitor.stop()

        let payload = await box.getLastPayload()
        try assertNotNil(payload)
        try assertEqual(payload?.type, .text)
        try assertEqual(payload?.textContent, "Testing Monitor")
    }

    static func testIgnoresSelfWrite() async throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.monitor.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: storage)
        let monitor = ClipboardMonitor(pasteboard: pasteboard, reader: reader, writer: writer, pollingInterval: 0.05)

        let box = TestCaptureBox()
        monitor.onNewPayload = { payload in
            await box.record(payload)
        }

        monitor.start()

        // Write via ClipboardWriter (marks this changeCount as a self-write)
        try writer.writeText("Self written text", to: pasteboard)
        monitor.checkForChanges()

        try await Task.sleep(nanoseconds: 200_000_000)
        monitor.stop()

        let count = await box.getCount()
        try assertEqual(count, 0, "Should not capture ClipBo self-writes")
    }

    static func testDeduplicatesConsecutiveIdenticalPayloads() async throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.clipbo.tests.monitor.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let reader = ClipboardReader()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)
        let writer = ClipboardWriter(imageStorage: storage)
        let monitor = ClipboardMonitor(pasteboard: pasteboard, reader: reader, writer: writer, pollingInterval: 0.05)

        let box = TestCaptureBox()
        monitor.onNewPayload = { payload in
            await box.record(payload)
        }

        monitor.start()

        // First copy
        pasteboard.clearContents()
        pasteboard.setString("Duplicate Text", forType: .string)
        monitor.checkForChanges()

        try await Task.sleep(nanoseconds: 200_000_000)

        // Second copy of identical string
        pasteboard.clearContents()
        pasteboard.setString("Duplicate Text", forType: .string)
        monitor.checkForChanges()

        try await Task.sleep(nanoseconds: 200_000_000)
        monitor.stop()

        let finalCount = await box.getCount()
        try assertEqual(finalCount, 1, "Duplicate consecutive entries must be deduplicated")
    }
}

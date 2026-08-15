import Foundation
import AppKit
import ClipBo

public struct ImageStorageTests {
    public static func runAll() throws {
        print("  ▶ Running ImageStorageTests...")
        try testSaveAndLoadImage()
        try testDeleteImage()
        try testClearAllImages()
        try testLoadNonexistentImageReturnsNil()
        try testSaveEmptyDataThrows()
        try testCleanupOrphanImages()
        print("  ✔ ImageStorageTests passed")
    }

    static func testSaveAndLoadImage() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBoTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)

        let testData = "FakeImageData".data(using: .utf8)!
        let id = UUID()

        let filename = try storage.saveImage(data: testData, id: id)
        try assertTrue(filename.contains(id.uuidString))

        let loaded = storage.loadImage(filenameOrPath: filename)
        try assertEqual(loaded, testData)
    }

    static func testDeleteImage() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBoTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)

        let testData = "DeleteMe".data(using: .utf8)!
        let filename = try storage.saveImage(data: testData)

        try assertNotNil(storage.loadImage(filenameOrPath: filename))

        try storage.deleteImage(filenameOrPath: filename)
        try assertNil(storage.loadImage(filenameOrPath: filename))
    }

    static func testClearAllImages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBoTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)

        try storage.saveImage(data: "1".data(using: .utf8)!)
        try storage.saveImage(data: "2".data(using: .utf8)!)
        try storage.saveImage(data: "3".data(using: .utf8)!)

        try storage.clearAllImages()

        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        try assertTrue(contents.isEmpty)
    }

    static func testLoadNonexistentImageReturnsNil() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBoTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)

        let loaded = storage.loadImage(filenameOrPath: "nonexistent.png")
        try assertNil(loaded)
    }

    static func testSaveEmptyDataThrows() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBoTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)

        try assertThrows({
            try storage.saveImage(data: Data())
        })
    }

    static func testCleanupOrphanImages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBoTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storage = ImageStorage(baseDirectory: tempDir)

        let file1 = try storage.saveImage(data: "KeepMe".data(using: .utf8)!)
        let file2 = try storage.saveImage(data: "Orphan1".data(using: .utf8)!)
        let file3 = try storage.saveImage(data: "Orphan2".data(using: .utf8)!)

        try assertEqual(storage.imageCount(), 3)

        // Clean up everything except file1
        storage.cleanupOrphanImages(validFilenames: [file1])

        try assertEqual(storage.imageCount(), 1)
        try assertNotNil(storage.loadImage(filenameOrPath: file1))
        try assertNil(storage.loadImage(filenameOrPath: file2))
        try assertNil(storage.loadImage(filenameOrPath: file3))
    }
}

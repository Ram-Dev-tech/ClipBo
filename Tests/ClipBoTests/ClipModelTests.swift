import Foundation
import ClipBo

public struct ClipModelTests {
    public static func runAll() throws {
        print("  ▶ Running ClipModelTests...")
        try testTextClipInitialization()
        try testImageClipInitialization()
        try testURLClipInitialization()
        try testClipCodable()
        print("  ✔ ClipModelTests passed")
    }

    static func testTextClipInitialization() throws {
        let clip = Clip.text("Hello ClipBo", sourceAppBundleId: "com.apple.Notes", sourceAppName: "Notes")
        
        try assertEqual(clip.type, .text)
        try assertEqual(clip.textContent, "Hello ClipBo")
        try assertNil(clip.imagePath)
        try assertFalse(clip.isStarred)
        try assertEqual(clip.sourceAppBundleId, "com.apple.Notes")
        try assertEqual(clip.sourceAppName, "Notes")
        try assertEqual(clip.charCount, 12)
        try assertEqual(clip.wordCount, 2)
        try assertTrue(clip.collectionIds.isEmpty)
        try assertTrue(clip.customMetadata.isEmpty)
        try assertNotNil(clip.id)
    }

    static func testImageClipInitialization() throws {
        let clip = Clip.image(imagePath: "test.png", width: 800, height: 600, sourceAppName: "Safari")
        
        try assertEqual(clip.type, .image)
        try assertEqual(clip.imagePath, "test.png")
        try assertNil(clip.textContent)
        try assertEqual(clip.imageWidth, 800)
        try assertEqual(clip.imageHeight, 600)
        try assertEqual(clip.sourceAppName, "Safari")
    }

    static func testURLClipInitialization() throws {
        let clip = Clip.url("https://apple.com")
        
        try assertEqual(clip.type, .url)
        try assertEqual(clip.textContent, "https://apple.com")
    }

    static func testClipCodable() throws {
        let original = Clip(
            id: UUID(),
            type: .text,
            textContent: "Sample text",
            imagePath: nil,
            createdAt: Date(),
            isStarred: true,
            sourceAppBundleId: "com.apple.Safari",
            sourceAppName: "Safari",
            charCount: 11,
            wordCount: 2,
            imageWidth: nil,
            imageHeight: nil,
            collectionIds: [UUID()],
            customMetadata: ["key1": "value1"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Clip.self, from: data)

        try assertEqual(decoded.id, original.id)
        try assertEqual(decoded.type, original.type)
        try assertEqual(decoded.textContent, original.textContent)
        try assertEqual(decoded.isStarred, original.isStarred)
        try assertEqual(decoded.sourceAppBundleId, original.sourceAppBundleId)
        try assertEqual(decoded.sourceAppName, original.sourceAppName)
        try assertEqual(decoded.charCount, original.charCount)
        try assertEqual(decoded.wordCount, original.wordCount)
        try assertEqual(decoded.collectionIds, original.collectionIds)
        try assertEqual(decoded.customMetadata["key1"], "value1")
    }
}

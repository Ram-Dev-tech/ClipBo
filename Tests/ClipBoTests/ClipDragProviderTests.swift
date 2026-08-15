import Foundation
import AppKit
import ClipBo

public struct ClipDragProviderTests {
    @MainActor
    public static func runAll() {
        print("  ▶ Running ClipDragProviderTests...")

        let imageStorage = ImageStorage()

        // 1. Text clip drag item
        print("    ▶ Testing text clip NSDraggingItem generation...")
        let textClip = Clip(id: UUID(), type: .text, textContent: "Hello ClipBo Drag", createdAt: Date())
        let textItem = ClipDragProvider.makeDraggingItem(for: textClip, imageStorage: imageStorage)
        assert(textItem != nil, "Text clip should generate a non-nil NSDraggingItem")
        assert(textItem?.item != nil, "NSDraggingItem should wrap a valid pasteboard writer")
        print("      ✔ Text clip NSDraggingItem created successfully")

        // 2. URL clip drag item
        print("    ▶ Testing URL clip NSDraggingItem generation...")
        let urlClip = Clip(id: UUID(), type: .url, textContent: "https://apple.com", createdAt: Date())
        let urlItem = ClipDragProvider.makeDraggingItem(for: urlClip, imageStorage: imageStorage)
        assert(urlItem != nil, "URL clip should generate a non-nil NSDraggingItem")
        print("      ✔ URL clip NSDraggingItem created successfully")

        // 3. Image clip drag item
        print("    ▶ Testing Image clip NSDraggingItem generation...")
        // Generate a 1x1 test PNG
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        
        let tiff = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiff)!
        let pngData = bitmap.representation(using: .png, properties: [:])!

        let imageClipId = UUID()
        let filename = try? imageStorage.saveImage(data: pngData, id: imageClipId)
        assert(filename != nil, "Failed to save test image data")

        let imageClip = Clip(id: imageClipId, type: .image, imagePath: filename, createdAt: Date())
        let imageItem = ClipDragProvider.makeDraggingItem(for: imageClip, imageStorage: imageStorage)
        assert(imageItem != nil, "Image clip should generate a non-nil NSDraggingItem with valid image data")
        
        // Clean up test image
        if let filename {
            try? imageStorage.deleteImage(filenameOrPath: filename)
        }
        print("      ✔ Image clip NSDraggingItem created with real NSImage payload")

        // 4. Code & Prompt clip drag items
        print("    ▶ Testing Code & Prompt clip NSDraggingItem generation...")
        let codeClip = Clip(id: UUID(), type: .code, textContent: "let x = 42", createdAt: Date())
        let codeItem = ClipDragProvider.makeDraggingItem(for: codeClip, imageStorage: imageStorage)
        assert(codeItem != nil, "Code clip should generate a valid NSDraggingItem")

        let promptClip = Clip(id: UUID(), type: .prompt, textContent: "Refactor this swift code", createdAt: Date())
        let promptItem = ClipDragProvider.makeDraggingItem(for: promptClip, imageStorage: imageStorage)
        assert(promptItem != nil, "Prompt clip should generate a valid NSDraggingItem")
        print("      ✔ Code & Prompt clip NSDraggingItem generated successfully")

        // 5. Empty clip handling
        print("    ▶ Testing Empty clip handling...")
        let emptyClip = Clip(id: UUID(), type: .text, textContent: "", createdAt: Date())
        let emptyItem = ClipDragProvider.makeDraggingItem(for: emptyClip, imageStorage: imageStorage)
        assert(emptyItem == nil, "Empty text clip should safely return nil")

        let missingImageClip = Clip(id: UUID(), type: .image, imagePath: "non_existent.png", createdAt: Date())
        let missingImageItem = ClipDragProvider.makeDraggingItem(for: missingImageClip, imageStorage: imageStorage)
        assert(missingImageItem == nil, "Missing image clip should safely return nil")
        print("      ✔ Empty/missing content safely returns nil without crashing")

        print("  ✔ ClipDragProviderTests passed")
    }
}

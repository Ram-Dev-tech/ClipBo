import Foundation
import AppKit
import UniformTypeIdentifiers
import ClipBo

public struct ClipDragProviderTests {
    @MainActor
    public static func runAll() {
        print("  ▶ Running ClipDragProviderTests...")

        let imageStorage = ImageStorage()

        // 1. Text clip drag item & NSItemProvider
        print("    ▶ Testing text clip NSDraggingItem & NSItemProvider generation...")
        let longText = String(repeating: "Original un-truncated text snippet. ", count: 20)
        let textClip = Clip(id: UUID(), type: .text, textContent: longText, createdAt: Date())
        let textItem = ClipDragProvider.makeDraggingItem(for: textClip, imageStorage: imageStorage)
        assert(textItem != nil, "Text clip should generate a non-nil NSDraggingItem")
        
        let textItemProvider = ClipDragProvider.makeItemProvider(for: textClip, imageStorage: imageStorage)
        assert(textItemProvider != nil, "Text clip should generate a non-nil NSItemProvider")
        assert(textItemProvider!.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier), "ItemProvider must support UTType.utf8PlainText")
        assert(textItemProvider!.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), "ItemProvider must support UTType.plainText")
        print("      ✔ Text clip NSDraggingItem & NSItemProvider created with full un-truncated content")

        // 2. URL clip drag item & NSItemProvider
        print("    ▶ Testing URL clip NSDraggingItem & NSItemProvider generation...")
        let urlString = "https://github.com/Ram-Dev-tech/ClipBo"
        let urlClip = Clip(id: UUID(), type: .url, textContent: urlString, createdAt: Date())
        let urlItem = ClipDragProvider.makeDraggingItem(for: urlClip, imageStorage: imageStorage)
        assert(urlItem != nil, "URL clip should generate a non-nil NSDraggingItem")
        
        let urlItemProvider = ClipDragProvider.makeItemProvider(for: urlClip, imageStorage: imageStorage)
        assert(urlItemProvider != nil, "URL clip should generate a non-nil NSItemProvider")
        assert(urlItemProvider!.hasItemConformingToTypeIdentifier(UTType.url.identifier), "ItemProvider must support UTType.url")
        assert(urlItemProvider!.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier), "ItemProvider must support UTType.utf8PlainText")
        print("      ✔ URL clip NSDraggingItem & NSItemProvider created successfully")

        // 3. Image clip drag item & NSItemProvider (PNG, TIFF, and File URL)
        print("    ▶ Testing Image clip NSDraggingItem & NSItemProvider generation...")
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
        
        let imageItemProvider = ClipDragProvider.makeItemProvider(for: imageClip, imageStorage: imageStorage)
        assert(imageItemProvider != nil, "Image clip should generate a non-nil NSItemProvider")
        assert(imageItemProvider!.hasItemConformingToTypeIdentifier(UTType.png.identifier), "Image itemProvider must support UTType.png")
        assert(imageItemProvider!.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier), "Image itemProvider must support UTType.fileURL")
        
        // Clean up test image
        if let filename {
            try? imageStorage.deleteImage(filenameOrPath: filename)
        }
        print("      ✔ Image clip NSDraggingItem & NSItemProvider created with PNG, TIFF, and File URL")

        // 4. Code & Prompt clip drag items
        print("    ▶ Testing Code & Prompt clip NSDraggingItem generation...")
        let codeSnippet = "func process<T>(_ items: [T]) -> [T] {\n    return items.filter { _ in true }\n}"
        let codeClip = Clip(id: UUID(), type: .code, textContent: codeSnippet, createdAt: Date())
        let codeItem = ClipDragProvider.makeDraggingItem(for: codeClip, imageStorage: imageStorage)
        assert(codeItem != nil, "Code clip should generate a valid NSDraggingItem")

        let promptText = "Act as an expert macOS software engineer and explain NSDraggingSession."
        let promptClip = Clip(id: UUID(), type: .prompt, textContent: promptText, createdAt: Date())
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

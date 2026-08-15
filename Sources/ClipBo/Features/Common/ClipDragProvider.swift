import Cocoa
import UniformTypeIdentifiers
import SwiftUI

/// Centralized provider that builds native macOS drag items and NSItemProviders for ClipBo clips.
/// Provides rich, standard multi-representation data (plain text, URLs, PNG, TIFF, and temporary file URLs)
/// so drag-and-drop works seamlessly with browsers (ChatGPT web, Google Docs, Notion), text editors,
/// IDEs (Xcode, VS Code), image apps (Preview, Slack, Notes), and Finder.
public struct ClipDragProvider {

    private static let dragCacheDirectory: URL = {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("com.clipbo.dragcache", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }()

    // MARK: - SwiftUI NSItemProvider Creation

    /// Builds an `NSItemProvider` for SwiftUI `.onDrag` interactions with complete, un-truncated content.
    public static func makeItemProvider(for clip: Clip, imageStorage: ImageStorage) -> NSItemProvider? {
        switch clip.type {
        case .text, .code, .prompt:
            guard let text = clip.textContent, !text.isEmpty else { return nil }
            let provider = NSItemProvider()

            // 1. UTF-8 Plain Text
            provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
                let data = text.data(using: .utf8)
                completion(data, nil)
                return nil
            }

            // 2. Plain Text
            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                let data = text.data(using: .utf8)
                completion(data, nil)
                return nil
            }

            // 3. Generic Text
            provider.registerDataRepresentation(forTypeIdentifier: UTType.text.identifier, visibility: .all) { completion in
                let data = text.data(using: .utf8)
                completion(data, nil)
                return nil
            }

            // String object registration for standard macOS pasteboard consumers
            provider.registerObject(text as NSString, visibility: .all)
            return provider

        case .url:
            guard let urlString = clip.textContent, !urlString.isEmpty else { return nil }
            let provider = NSItemProvider()

            // 1. Native URL representation
            if let url = URL(string: urlString) {
                provider.registerItem(forTypeIdentifier: UTType.url.identifier) { (completion, _, _) in
                    completion(url as NSURL, nil)
                }
                provider.registerObject(url as NSURL, visibility: .all)
            }

            // 2. Plain Text representation for text-only destinations
            provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
                let data = urlString.data(using: .utf8)
                completion(data, nil)
                return nil
            }

            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                let data = urlString.data(using: .utf8)
                completion(data, nil)
                return nil
            }
            return provider

        case .image:
            guard let path = clip.imagePath,
                  let rawData = imageStorage.loadImage(filenameOrPath: path),
                  let nsImage = NSImage(data: rawData) else { return nil }

            let provider = NSItemProvider()
            let pngData = extractPNGData(from: nsImage, fallbackRaw: rawData)

            // 1. Raw PNG Data representation (ChatGPT web, Chrome, Safari, Slack, Pixelmator)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                completion(pngData, nil)
                return nil
            }

            // 2. Raw TIFF Data representation (AppKit legacy consumers)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.tiff.identifier, visibility: .all) { completion in
                let tiff = nsImage.tiffRepresentation ?? pngData
                completion(tiff, nil)
                return nil
            }

            // 3. Generic Image
            provider.registerDataRepresentation(forTypeIdentifier: UTType.image.identifier, visibility: .all) { completion in
                completion(pngData, nil)
                return nil
            }

            // 4. File URL representation for Finder / file-upload drop zones
            if let tempFileURL = createTemporaryImageFile(data: pngData, clipId: clip.id) {
                provider.registerItem(forTypeIdentifier: UTType.fileURL.identifier) { (completion, _, _) in
                    completion(tempFileURL as NSURL, nil)
                }
            }

            // NSImage object registration
            provider.registerObject(nsImage, visibility: .all)
            return provider
        }
    }

    // MARK: - AppKit NSDraggingItem Creation

    /// Creates an `NSDraggingItem` for native AppKit `beginDraggingSession(with:event:source:)`.
    @MainActor
    public static func makeDraggingItem(for clip: Clip, imageStorage: ImageStorage) -> NSDraggingItem? {
        switch clip.type {
        case .text, .code, .prompt:
            guard let text = clip.textContent, !text.isEmpty else { return nil }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(text, forType: .string)
            pasteboardItem.setString(text, forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
            pasteboardItem.setString(text, forType: NSPasteboard.PasteboardType("public.text"))

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let preview = textPreviewImage(text, isCode: clip.type == .code)
            draggingItem.setDraggingFrame(NSRect(origin: .zero, size: preview.size), contents: preview)
            return draggingItem

        case .url:
            guard let urlString = clip.textContent, !urlString.isEmpty else { return nil }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(urlString, forType: .string)
            pasteboardItem.setString(urlString, forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
            if let url = URL(string: urlString) {
                pasteboardItem.setString(url.absoluteString, forType: .URL)
                pasteboardItem.setString(url.absoluteString, forType: NSPasteboard.PasteboardType("public.url"))
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let preview = urlPreviewImage(urlString)
            draggingItem.setDraggingFrame(NSRect(origin: .zero, size: preview.size), contents: preview)
            return draggingItem

        case .image:
            guard let path = clip.imagePath,
                  let rawData = imageStorage.loadImage(filenameOrPath: path),
                  let nsImage = NSImage(data: rawData) else { return nil }

            let pasteboardItem = NSPasteboardItem()
            let pngData = extractPNGData(from: nsImage, fallbackRaw: rawData)

            pasteboardItem.setData(pngData, forType: .png)
            pasteboardItem.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))
            if let tiff = nsImage.tiffRepresentation {
                pasteboardItem.setData(tiff, forType: .tiff)
            }

            // Provide temporary file URL for Finder and file-drop applications
            if let tempFileURL = createTemporaryImageFile(data: pngData, clipId: clip.id) {
                pasteboardItem.setString(tempFileURL.absoluteString, forType: .fileURL)
                pasteboardItem.setString(tempFileURL.path, forType: NSPasteboard.PasteboardType("public.file-url"))
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let thumbSize = NSSize(width: 80, height: 80)
            let thumb = nsImage.scaled(to: thumbSize)
            draggingItem.setDraggingFrame(NSRect(origin: .zero, size: thumb.size), contents: thumb)
            return draggingItem
        }
    }

    // MARK: - Temporary File Management

    /// Writes PNG image data to a temporary file in a managed cache directory for Finder/web drops.
    public static func createTemporaryImageFile(data: Data, clipId: UUID) -> URL? {
        cleanupOldTemporaryFiles()
        let filename = "ClipBo_Image_\(clipId.uuidString.prefix(8)).png"
        let fileURL = dragCacheDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func cleanupOldTemporaryFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dragCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let now = Date()
        for file in files {
            if let attrs = try? fm.attributesOfItem(atPath: file.path),
               let modDate = attrs[.modificationDate] as? Date,
               now.timeIntervalSince(modDate) > 300 { // 5 minutes old
                try? fm.removeItem(at: file)
            }
        }
    }

    // MARK: - Data Conversion Helpers

    private static func extractPNGData(from image: NSImage, fallbackRaw: Data) -> Data {
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        return fallbackRaw
    }

    // MARK: - Drag Previews

    @MainActor
    private static func textPreviewImage(_ text: String, isCode: Bool) -> NSImage {
        let size = NSSize(width: 220, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()

        let bgRect = NSRect(origin: .zero, size: size)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
        if isCode {
            NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 0.95).setFill()
        } else {
            NSColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 0.95).setFill()
        }
        bgPath.fill()

        let font = isCode ? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) : NSFont.systemFont(ofSize: 11, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let previewSnippet = String(text.prefix(35)).replacingOccurrences(of: "\n", with: " ")
        (previewSnippet as NSString).draw(at: NSPoint(x: 8, y: 9), withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    @MainActor
    private static func urlPreviewImage(_ urlString: String) -> NSImage {
        let size = NSSize(width: 220, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()

        let bgRect = NSRect(origin: .zero, size: size)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
        NSColor(red: 0.10, green: 0.35, blue: 0.65, alpha: 0.95).setFill()
        bgPath.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let previewSnippet = String(urlString.prefix(35))
        (previewSnippet as NSString).draw(at: NSPoint(x: 8, y: 9), withAttributes: attrs)

        image.unlockFocus()
        return image
    }
}

// MARK: - NSImage Aspect Ratio Scaling

extension NSImage {
    /// Returns a copy of the image scaled to the target bounds preserving aspect ratio.
    public func scaled(to targetSize: NSSize) -> NSImage {
        guard size.width > 0, size.height > 0 else { return self }
        let aspectWidth = targetSize.width / size.width
        let aspectHeight = targetSize.height / size.height
        let scale = min(aspectWidth, aspectHeight)
        let scaledSize = NSSize(width: max(size.width * scale, 1), height: max(size.height * scale, 1))

        let result = NSImage(size: scaledSize)
        result.lockFocus()
        draw(in: NSRect(origin: .zero, size: scaledSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        result.unlockFocus()
        return result
    }
}

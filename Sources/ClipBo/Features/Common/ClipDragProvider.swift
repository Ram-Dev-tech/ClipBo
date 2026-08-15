import Cocoa
import UniformTypeIdentifiers
import SwiftUI

/// Centralised provider that builds native AppKit drag items for ClipBo clip types.
/// Provides proper data types so drag-and-drop works with browsers, text editors, and Finder.
public struct ClipDragProvider {

    /// Creates an `NSDraggingItem` for a clip, suitable for `beginDraggingSession(with:event:source:)`.
    /// Returns nil if the clip has no content or image data cannot be loaded.
    @MainActor
    public static func makeDraggingItem(for clip: Clip, imageStorage: ImageStorage) -> NSDraggingItem? {
        switch clip.type {
        case .text, .code, .prompt:
            guard let text = clip.textContent, !text.isEmpty else { return nil }
            let item = NSDraggingItem(pasteboardWriter: text as NSString)
            // Simple text preview
            let previewText = String(text.prefix(60))
            item.setDraggingFrame(NSRect(x: 0, y: 0, width: 200, height: 28), contents: textPreviewImage(previewText))
            return item

        case .url:
            guard let urlString = clip.textContent, !urlString.isEmpty else { return nil }
            let writer = NSPasteboardItem()
            writer.setString(urlString, forType: .string)
            if let url = URL(string: urlString) {
                writer.setString(url.absoluteString, forType: .URL)
            }
            let item = NSDraggingItem(pasteboardWriter: writer)
            item.setDraggingFrame(NSRect(x: 0, y: 0, width: 200, height: 28), contents: textPreviewImage(urlString))
            return item

        case .image:
            guard let path = clip.imagePath,
                  let data = imageStorage.loadImage(filenameOrPath: path),
                  let nsImage = NSImage(data: data) else { return nil }
            let item = NSDraggingItem(pasteboardWriter: nsImage)
            // Scaled preview thumbnail
            let thumbSize = NSSize(width: 80, height: 80)
            let thumb = nsImage.scaled(to: thumbSize)
            item.setDraggingFrame(NSRect(origin: .zero, size: thumbSize), contents: thumb)
            return item
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private static func textPreviewImage(_ text: String) -> NSImage {
        let size = NSSize(width: 200, height: 28)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let truncated = String(text.prefix(40))
        (truncated as NSString).draw(at: NSPoint(x: 6, y: 7), withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}

// MARK: - NSImage Scaling

extension NSImage {
    /// Returns a copy of the image scaled to the given size preserving aspect ratio.
    func scaled(to targetSize: NSSize) -> NSImage {
        let aspectWidth = targetSize.width / size.width
        let aspectHeight = targetSize.height / size.height
        let scale = min(aspectWidth, aspectHeight)
        let scaledSize = NSSize(width: size.width * scale, height: size.height * scale)

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

// MARK: - Public Drag View

/// Transparent NSView overlay that handles native drag-and-drop initiation.
/// Uses a minimum drag threshold (4pt) to distinguish from single/double-click.
/// Supports text, URL, code, prompt, and image clips via ClipDragProvider.
public struct ClipDragView: NSViewRepresentable {
    public let clip: Clip
    public let imageStorage: ImageStorage
    public let onDragCompleted: (() -> Void)?

    public init(clip: Clip, imageStorage: ImageStorage, onDragCompleted: (() -> Void)? = nil) {
        self.clip = clip
        self.imageStorage = imageStorage
        self.onDragCompleted = onDragCompleted
    }

    public func makeNSView(context: Context) -> DragHandleView {
        let v = DragHandleView()
        v.clip = clip
        v.imageStorage = imageStorage
        v.onDragCompleted = onDragCompleted
        return v
    }

    public func updateNSView(_ nsView: DragHandleView, context: Context) {
        nsView.clip = clip
        nsView.imageStorage = imageStorage
        nsView.onDragCompleted = onDragCompleted
    }

    public final class DragHandleView: NSView, NSDraggingSource {
        public var clip: Clip?
        public var imageStorage: ImageStorage?
        public var onDragCompleted: (() -> Void)?

        private var mouseDownLocation: NSPoint?
        private let dragThreshold: CGFloat = 4.0

        public override func mouseDown(with event: NSEvent) {
            mouseDownLocation = event.locationInWindow
        }

        public override func mouseDragged(with event: NSEvent) {
            guard let startLoc = mouseDownLocation,
                  let clip, let imageStorage else { return }
            let current = event.locationInWindow
            let dx = current.x - startLoc.x
            let dy = current.y - startLoc.y
            guard sqrt(dx * dx + dy * dy) >= dragThreshold else { return }
            mouseDownLocation = nil

            guard let draggingItem = ClipDragProvider.makeDraggingItem(for: clip, imageStorage: imageStorage) else { return }
            let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
            session.animatesToStartingPositionsOnCancelOrFail = true
        }

        public override func mouseUp(with event: NSEvent) {
            mouseDownLocation = nil
        }

        public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            return [.copy, .move, .link]
        }

        public func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            if operation != [] {
                Task { @MainActor in
                    self.onDragCompleted?()
                }
            }
        }
    }
}

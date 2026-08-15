import Cocoa
import SwiftUI

/// Custom resizable borderless floating NSPanel for the Spotlight-inspired Quick Overlay.
public final class FloatingOverlayPanel: NSPanel, NSWindowDelegate {
    public var onDismiss: (() -> Void)?
    public var onGeometryChanged: ((NSRect) -> Void)?

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.animationBehavior = .utilityWindow
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.minSize = NSSize(width: OverlayGeometry.minWidth, height: OverlayGeometry.minHeight)
        self.maxSize = NSSize(width: OverlayGeometry.maxWidth, height: OverlayGeometry.maxHeight)

        self.delegate = self
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func resignKey() {
        super.resignKey()
        onDismiss?()
    }

    // MARK: - NSWindowDelegate

    public func windowDidMove(_ notification: Notification) {
        onGeometryChanged?(frame)
    }

    public func windowDidResize(_ notification: Notification) {
        onGeometryChanged?(frame)
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        onGeometryChanged?(frame)
    }

    // MARK: - Positioning & Display Recovery

    /// Positions the overlay panel using persisted geometry or safely centers on the active display.
    public func restoreOrCenterGeometry(saved: OverlayGeometry) {
        let width = min(max(saved.width, OverlayGeometry.minWidth), OverlayGeometry.maxWidth)
        let height = min(max(saved.height, OverlayGeometry.minHeight), OverlayGeometry.maxHeight)

        // 1. Check if saved position is valid and visible on any current screen
        if let origX = saved.originX, let origY = saved.originY {
            let candidateRect = NSRect(x: origX, y: origY, width: width, height: height)
            let isVisible = NSScreen.screens.contains { screen in
                let intersection = screen.visibleFrame.intersection(candidateRect)
                return intersection.width >= 100 && intersection.height >= 100
            }

            if isVisible {
                setFrame(candidateRect, display: true)
                return
            }
        }

        // 2. Fallback: Center in the upper third of the active display
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main ?? screens.first

        guard let screen = targetScreen else {
            setFrame(NSRect(x: 100, y: 100, width: width, height: height), display: true)
            return
        }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - height) * 0.72

        let finalRect = NSRect(x: x, y: y, width: width, height: height)
        setFrame(finalRect, display: true)
    }
}

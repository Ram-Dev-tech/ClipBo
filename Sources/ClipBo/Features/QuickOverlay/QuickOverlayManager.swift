import Cocoa
import SwiftUI
import OSLog

/// Coordinates the presentation, positioning, and lifecycle of the Spotlight-inspired Quick Overlay.
@MainActor
public final class QuickOverlayManager: NSObject {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "QuickOverlayManager")
    
    private var panel: FloatingOverlayPanel?
    private let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let saved = coordinator.settingsService.settings.overlayGeometry
        let initialRect = NSRect(
            x: saved.originX ?? 0,
            y: saved.originY ?? 0,
            width: saved.width,
            height: saved.height
        )
        
        let overlayPanel = FloatingOverlayPanel(contentRect: initialRect)
        
        let rootView = QuickOverlayView(
            coordinator: coordinator,
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        overlayPanel.contentViewController = NSHostingController(rootView: rootView)
        overlayPanel.onDismiss = { [weak self] in
            self?.hide()
        }

        overlayPanel.onGeometryChanged = { [weak self] frame in
            guard let self = self else { return }
            self.coordinator.settingsService.updateOverlayGeometry(
                width: Double(frame.width),
                height: Double(frame.height),
                originX: Double(frame.origin.x),
                originY: Double(frame.origin.y)
            )
        }

        self.panel = overlayPanel
        logger.info("QuickOverlayManager initialized with resizable floating panel")
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Presents the floating Quick Overlay restored at saved position or centered on the currently active display.
    public func show() {
        guard let panel = panel else { return }

        Task {
            await coordinator.reloadRecentClips()
        }

        let saved = coordinator.settingsService.settings.overlayGeometry
        panel.restoreOrCenterGeometry(saved: saved)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("Quick Overlay presented on active display")
    }

    /// Hides the Quick Overlay.
    public func hide() {
        guard let panel = panel, panel.isVisible else { return }
        panel.orderOut(nil)
        logger.info("Quick Overlay dismissed")
    }

    /// Toggles the Quick Overlay visibility.
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}

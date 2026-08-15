import Cocoa
import SwiftUI
import OSLog

/// Manages the macOS Menu Bar status item and verification popover.
@MainActor
public final class MenuBarManager: NSObject {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "MenuBarManager")
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let image = ClipBoIconProvider.menuBarTemplateImage()
            button.image = image
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: DesignTokens.Dimensions.menuBarWidth, height: DesignTokens.Dimensions.menuBarHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelView(
                coordinator: coordinator,
                onDismiss: { [weak self] in
                    self?.closePopover()
                }
            )
        )
        self.popover = popover

        logger.info("MenuBarManager initialized with status item")
    }

    public var isShown: Bool {
        popover?.isShown ?? false
    }

    @objc public func togglePopover(_ sender: AnyObject?) {
        guard let popover = popover, statusItem?.button != nil else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    /// Opens the Menu Bar Panel popover, reloads clips, and makes it key.
    public func showPopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        Task {
            await coordinator.reloadRecentClips()
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Closes the Menu Bar Panel popover.
    public func closePopover() {
        guard let popover = popover, popover.isShown else { return }
        popover.performClose(nil)
        logger.info("MenuBarManager popover closed")
    }
}

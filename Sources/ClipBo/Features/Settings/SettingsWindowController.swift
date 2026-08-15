import Cocoa
import SwiftUI

/// Manages the lifecycle and display of the native ClipBo Settings window.
@MainActor
public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private var hostingController: NSHostingController<SettingsView>?

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipBo Settings"
        window.setFrameAutosaveName("ClipBoSettingsWindow")
        window.isReleasedWhenClosed = false

        // Native macOS Space & Full-screen collection behaviors:
        // - .moveToActiveSpace: moves window to the currently active desktop/Space when presented
        // - .fullScreenAuxiliary: allows presentation alongside/above native macOS full-screen applications
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Floating level ensures Settings floats cleanly over full-screen application spaces without dropping behind
        window.level = .floating

        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Opens or brings the Settings window to the front on the user's active display and Space.
    public func show(settingsService: SettingsService, coordinator: AppCoordinator) {
        let rootView = SettingsView(settingsService: settingsService, coordinator: coordinator)

        if let hosting = hostingController {
            hosting.rootView = rootView
        } else {
            let hosting = NSHostingController(rootView: rootView)
            self.hostingController = hosting
            window?.contentViewController = hosting
        }

        if let window = self.window {
            // Determine active screen based on cursor location (where user clicked) or main screen
            let mouseLoc = NSEvent.mouseLocation
            let activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main ?? window.screen

            if let screen = activeScreen {
                let screenFrame = screen.visibleFrame
                let windowSize = window.frame.size
                let targetOrigin = NSPoint(
                    x: screenFrame.midX - (windowSize.width / 2),
                    y: screenFrame.midY - (windowSize.height / 2)
                )

                // If window is on a different screen or outside visible frame, reposition to active screen
                if window.screen != screen || !screenFrame.contains(window.frame.origin) {
                    window.setFrameOrigin(targetOrigin)
                }
            }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

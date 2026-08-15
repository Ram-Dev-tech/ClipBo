import Cocoa
import SwiftUI
import OSLog

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "AppDelegate")
    
    private var coordinator: AppCoordinator?
    private var menuBarManager: MenuBarManager?
    private var quickOverlayManager: QuickOverlayManager?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu-bar accessory utility without Dock icon
        NSApp.setActivationPolicy(.accessory)
        
        do {
            let repository = try CoreDataClipRepository(inMemory: false)
            let imageStorage = ImageStorage()
            let coordinator = AppCoordinator(repository: repository, imageStorage: imageStorage)
            self.coordinator = coordinator

            // Setup Menu Bar Panel (Interface 1)
            self.menuBarManager = MenuBarManager(coordinator: coordinator)

            // Setup Quick Overlay (Interface 2)
            let overlayManager = QuickOverlayManager(coordinator: coordinator)
            self.quickOverlayManager = overlayManager

            // Register Global Shortcuts (from persisted AppSettings)
            GlobalShortcutManager.shared.onQuickOverlayTriggered = { [weak overlayManager] in
                Task { @MainActor in
                    overlayManager?.toggle()
                }
            }
            GlobalShortcutManager.shared.onQuickCaptureTriggered = { [weak coordinator] in
                Task { @MainActor in
                    await coordinator?.captureSelection()
                }
            }
            GlobalShortcutManager.shared.onMenuBarPanelTriggered = { [weak menuBarManager] in
                Task { @MainActor in
                    menuBarManager?.togglePopover(nil)
                }
            }
            
            let overlayShortcut = coordinator.settingsService.settings.quickOverlayShortcut
            let captureShortcut = coordinator.settingsService.settings.quickCaptureShortcut
            let menuBarShortcut = coordinator.settingsService.settings.menuBarPanelShortcut
            GlobalShortcutManager.shared.registerQuickOverlayShortcut(keyCode: overlayShortcut.keyCode, modifiers: overlayShortcut.modifiers)
            GlobalShortcutManager.shared.registerQuickCaptureShortcut(keyCode: captureShortcut.keyCode, modifiers: captureShortcut.modifiers)
            GlobalShortcutManager.shared.registerMenuBarPanelShortcut(keyCode: menuBarShortcut.keyCode, modifiers: menuBarShortcut.modifiers)

            // Start clipboard engine
            Task { @MainActor in
                await coordinator.start()
            }
            logger.info("ClipBo application initialized successfully with dual interfaces")
        } catch {
            logger.critical("Failed to initialize CoreData repository: \(error.localizedDescription)")
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        GlobalShortcutManager.shared.unregisterAll()
        coordinator?.stop()
        logger.info("ClipBo application terminated cleanly")
    }
}

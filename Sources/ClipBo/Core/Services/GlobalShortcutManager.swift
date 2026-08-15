import Cocoa
import Carbon
import OSLog

/// Manages global keyboard shortcuts using the native Carbon HotKey API.
public final class GlobalShortcutManager: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "GlobalShortcutManager")
    
    public static let shared = GlobalShortcutManager()
    
    private var quickOverlayHotKeyRef: EventHotKeyRef?
    private var quickCaptureHotKeyRef: EventHotKeyRef?
    private var menuBarPanelHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    public var onQuickOverlayTriggered: (@Sendable () -> Void)?
    public var onQuickCaptureTriggered: (@Sendable () -> Void)?
    public var onMenuBarPanelTriggered: (@Sendable () -> Void)?

    public init() {
        setupCarbonEventHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func setupCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Use GetEventDispatcherTarget() for reliable global hotkey event interception
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(event)
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
        
        if status == noErr {
            logger.info("Carbon global hotkey event handler installed successfully.")
        } else {
            logger.error("Failed to install Carbon event handler. OSStatus: \(status)")
        }
    }

    private func handleHotKeyEvent(_ event: EventRef) {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            logger.error("Failed to extract EventHotKeyID parameter: \(status)")
            return
        }

        logger.debug("Received HotKey event (signature: \(hotKeyID.signature), id: \(hotKeyID.id))")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if hotKeyID.id == 1 {
                self.logger.info("Dispatching Quick Overlay action (ID 1)")
                self.onQuickOverlayTriggered?()
            } else if hotKeyID.id == 2 {
                self.logger.info("Dispatching Quick Selection Capture action (ID 2)")
                self.onQuickCaptureTriggered?()
            } else if hotKeyID.id == 3 {
                self.logger.info("Dispatching Menu Bar Panel action (ID 3)")
                self.onMenuBarPanelTriggered?()
            }
        }
    }

    /// Registers the default global shortcuts (Quick Overlay: ⌘ ⇧ V, Quick Capture: ⌥ ⌘ C, Menu Bar Panel: ⌘ ⇧ Space).
    public func registerDefaultShortcuts() {
        let overlayStatus = registerQuickOverlayShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
        let captureStatus = registerQuickCaptureShortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey))
        let menuBarStatus = registerMenuBarPanelShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey))
        logger.info("Default shortcuts registered — Overlay: \(overlayStatus), Capture: \(captureStatus), MenuBar: \(menuBarStatus)")
    }

    /// Registers the Quick Overlay shortcut (ID 1).
    @discardableResult
    public func registerQuickOverlayShortcut(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        if let ref = quickOverlayHotKeyRef {
            UnregisterEventHotKey(ref)
            quickOverlayHotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // 'CLIP', 1
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &quickOverlayHotKeyRef)

        if status == noErr {
            logger.info("Quick Overlay shortcut registered successfully (keyCode: \(keyCode), modifiers: \(modifiers))")
        } else {
            logger.error("Failed to register Quick Overlay hotkey. OSStatus: \(status) (error: \(self.explainOSStatus(status)))")
        }
        return status
    }

    /// Registers the Quick Capture shortcut (ID 2).
    @discardableResult
    public func registerQuickCaptureShortcut(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        if let ref = quickCaptureHotKeyRef {
            UnregisterEventHotKey(ref)
            quickCaptureHotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 2) // 'CLIP', 2
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &quickCaptureHotKeyRef)

        if status == noErr {
            logger.info("Quick Capture shortcut registered successfully (keyCode: \(keyCode), modifiers: \(modifiers))")
        } else {
            logger.error("Failed to register Quick Capture hotkey. OSStatus: \(status) (error: \(self.explainOSStatus(status)))")
        }
        return status
    }

    /// Registers the Menu Bar Panel shortcut (ID 3).
    @discardableResult
    public func registerMenuBarPanelShortcut(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        if let ref = menuBarPanelHotKeyRef {
            UnregisterEventHotKey(ref)
            menuBarPanelHotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 3) // 'CLIP', 3
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &menuBarPanelHotKeyRef)

        if status == noErr {
            logger.info("Menu Bar Panel shortcut registered successfully (keyCode: \(keyCode), modifiers: \(modifiers))")
        } else {
            logger.error("Failed to register Menu Bar Panel hotkey. OSStatus: \(status) (error: \(self.explainOSStatus(status)))")
        }
        return status
    }

    /// Unregisters all registered global hotkeys.
    public func unregisterAll() {
        if let ref = quickOverlayHotKeyRef {
            UnregisterEventHotKey(ref)
            quickOverlayHotKeyRef = nil
        }
        if let ref = quickCaptureHotKeyRef {
            UnregisterEventHotKey(ref)
            quickCaptureHotKeyRef = nil
        }
        if let ref = menuBarPanelHotKeyRef {
            UnregisterEventHotKey(ref)
            menuBarPanelHotKeyRef = nil
        }
        logger.info("All global hotkeys unregistered.")
    }

    private func explainOSStatus(_ status: OSStatus) -> String {
        switch status {
        case -9878: return "eventHotKeyExistsErr (hotkey is already registered by another application)"
        case -9879: return "eventHotKeyInvalidErr (invalid hotkey parameters)"
        case 0: return "noErr"
        default: return "OSStatus code \(status)"
        }
    }
}

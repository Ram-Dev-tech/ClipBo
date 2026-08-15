import Cocoa
import ApplicationServices
import OSLog

/// Background monitor that detects modifier-assisted text and image selection gestures (e.g. ⌘ + drag/select).
/// When a selection gesture finishes while the configured modifier is held, triggers a background Quick Capture
/// without modifying NSPasteboard or simulating ⌘C.
public final class SelectionModifierCaptureManager: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "SelectionModifierCaptureManager")

    public static let shared = SelectionModifierCaptureManager()

    public var onSelectionCaptureTriggered: (@MainActor () -> Void)?

    private var monitor: Any?
    private var activeModifier: SelectionModifier = .command
    private var isSelectionGestureActive: Bool = false
    private var wasModifierHeldDuringGesture: Bool = false
    private var mouseDownPoint: NSPoint? = nil
    private let dragDistanceThreshold: CGFloat = 4.0

    public init() {}

    /// Starts global event monitoring for the given selection modifier.
    public func start(modifier: SelectionModifier = .command) {
        guard monitor == nil else {
            self.activeModifier = modifier
            return
        }

        self.activeModifier = modifier

        // Listen for global mouse down, drag, release, and modifier flag transitions
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]
        ) { [weak self] event in
            self?.handleGlobalEvent(event)
        }

        logger.info("SelectionModifierCaptureManager started with modifier: \(modifier.rawValue)")
    }

    /// Stops global event monitoring.
    public func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isSelectionGestureActive = false
        wasModifierHeldDuringGesture = false
        mouseDownPoint = nil
        logger.info("SelectionModifierCaptureManager stopped")
    }

    /// Updates the active selection modifier in real-time without restarting the monitor.
    public func updateModifier(_ modifier: SelectionModifier) {
        self.activeModifier = modifier
        logger.info("SelectionModifierCaptureManager modifier updated to: \(modifier.rawValue)")
    }

    // MARK: - Event Processing

    private func handleGlobalEvent(_ event: NSEvent) {
        let modifierHeld = event.modifierFlags.contains(activeModifier.eventFlags)

        switch event.type {
        case .leftMouseDown:
            mouseDownPoint = event.locationInWindow
            isSelectionGestureActive = false
            wasModifierHeldDuringGesture = modifierHeld

        case .leftMouseDragged:
            if modifierHeld || wasModifierHeldDuringGesture {
                if let start = mouseDownPoint {
                    let current = event.locationInWindow
                    let dx = current.x - start.x
                    let dy = current.y - start.y
                    if (dx * dx + dy * dy) >= (dragDistanceThreshold * dragDistanceThreshold) {
                        isSelectionGestureActive = true
                        wasModifierHeldDuringGesture = true
                    }
                }
            }

        case .leftMouseUp:
            let isMultiClickSelection = (event.clickCount >= 2 && modifierHeld)
            let shouldTrigger = (isSelectionGestureActive && wasModifierHeldDuringGesture) || isMultiClickSelection

            // Reset tracking state
            isSelectionGestureActive = false
            wasModifierHeldDuringGesture = false
            mouseDownPoint = nil

            if shouldTrigger {
                logger.info("Modifier selection gesture completed with \(self.activeModifier.rawValue). Triggering background capture...")
                // Allow target application 50ms to finalize its AXSelectedText attribute
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    self.onSelectionCaptureTriggered?()
                }
            }

        case .flagsChanged:
            // If modifier is released before any drag occurred, reset flag tracking
            if !modifierHeld && !isSelectionGestureActive {
                wasModifierHeldDuringGesture = false
            }

        default:
            break
        }
    }

    deinit {
        stop()
    }
}

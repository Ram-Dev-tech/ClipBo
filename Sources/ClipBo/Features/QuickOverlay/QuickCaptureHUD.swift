import Cocoa
import SwiftUI
import OSLog

// MARK: - HUD State

/// The display state of the Quick Capture HUD.
public enum QuickCaptureHUDState: Equatable, Sendable {
    /// Waiting for the user to have content selected.
    case arming(shortcut: String)
    /// Content was successfully captured.
    case captured(String)
    /// Capture failed with a human-readable reason.
    case failed(String)
    /// Accessibility permission is required.
    case accessibilityRequired
}

// MARK: - HUD Manager

/// Manages the lifecycle of the minimal floating Quick Capture HUD panel.
/// The HUD is non-activating and never steals focus from the user's active application.
@MainActor
public final class QuickCaptureHUDManager {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "QuickCaptureHUD")
    private var panel: NSPanel?
    private var hostingController: NSHostingController<QuickCaptureHUDView>?
    private var dismissTask: Task<Void, Never>?
    private var escMonitor: Any?

    public init() {}

    /// Shows the HUD with the given state for the specified duration (seconds).
    /// Pass `duration: nil` to keep the HUD open until explicitly dismissed.
    public func show(state: QuickCaptureHUDState, autoDismissAfter duration: TimeInterval? = nil) {
        dismissTask?.cancel()
        dismissTask = nil

        let hudView = QuickCaptureHUDView(state: state, onDismiss: { [weak self] in
            Task { @MainActor in self?.dismiss() }
        })

        if let existingController = hostingController {
            existingController.rootView = hudView
        } else {
            let controller = NSHostingController(rootView: hudView)
            hostingController = controller

            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 54),
                styleMask: [.fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.isMovableByWindowBackground = false
            p.isReleasedWhenClosed = false
            p.animationBehavior = .utilityWindow
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentViewController = controller
            panel = p

            installEscMonitor()
        }

        positionNearMenuBar()
        panel?.orderFront(nil)
        logger.info("QuickCaptureHUD shown with state: \(String(describing: state))")

        if let duration {
            dismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.dismiss()
            }
        }
    }

    /// Hides the HUD immediately.
    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        removeEscMonitor()
        logger.info("QuickCaptureHUD dismissed")
    }

    /// Transitions to a new state without re-positioning.
    public func transition(to state: QuickCaptureHUDState, autoDismissAfter duration: TimeInterval? = nil) {
        guard let controller = hostingController, panel?.isVisible == true else {
            show(state: state, autoDismissAfter: duration)
            return
        }
        dismissTask?.cancel()
        dismissTask = nil
        controller.rootView = QuickCaptureHUDView(state: state, onDismiss: { [weak self] in
            Task { @MainActor in self?.dismiss() }
        })
        if let duration {
            dismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.dismiss()
            }
        }
    }

    // MARK: - Private

    private func positionNearMenuBar() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.frame
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 54
        let x = frame.origin.x + (frame.width - panelWidth) / 2
        let y = frame.origin.y + frame.height - NSStatusBar.system.thickness - panelHeight - 8
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    private func installEscMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in self?.dismiss() }
            }
        }
    }

    private func removeEscMonitor() {
        if let m = escMonitor {
            NSEvent.removeMonitor(m)
            escMonitor = nil
        }
    }

    deinit {
        if let m = escMonitor { NSEvent.removeMonitor(m) }
    }
}

// MARK: - SwiftUI HUD View

struct QuickCaptureHUDView: View {
    let state: QuickCaptureHUDState
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(primaryText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let hint = hintText {
                    Text(hint)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320, height: 54)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if state == .accessibilityRequired {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
                onDismiss()
            }
        }
    }

    private var primaryText: String {
        switch state {
        case .arming:
            return "✦ ClipBo — Select content to capture"
        case .captured(let summary):
            return "Captured: \(summary)"
        case .failed(let reason):
            return reason
        case .accessibilityRequired:
            return "Accessibility permission required"
        }
    }

    private var hintText: String? {
        switch state {
        case .arming:
            return "Press Esc to cancel"
        case .captured:
            return nil
        case .failed:
            return "No content was captured"
        case .accessibilityRequired:
            return "Enable in System Settings → Privacy → Accessibility"
        }
    }

    private var iconName: String {
        switch state {
        case .arming: return "record.circle"
        case .captured: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        case .accessibilityRequired: return "lock.shield"
        }
    }

    private var iconColor: Color {
        switch state {
        case .arming: return .accentColor
        case .captured: return .green
        case .failed: return .orange
        case .accessibilityRequired: return .orange
        }
    }
}

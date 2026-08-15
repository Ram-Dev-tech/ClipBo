import Foundation
import ServiceManagement
import OSLog

public enum LaunchAtLoginError: LocalizedError, Sendable {
    case serviceNotFound
    case registrationFailed(String)
    case requiresApproval

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound:
            return "Launch at login service was not found."
        case .registrationFailed(let msg):
            return "Failed to register launch item: \(msg)"
        case .requiresApproval:
            return "Launch at login requires user approval in System Settings."
        }
    }
}

/// Manages Launch-at-Login functionality via `SMAppService`.
public final class LaunchAtLoginManager: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "LaunchAtLoginManager")
    
    public static let shared = LaunchAtLoginManager()

    public init() {}

    /// Whether launch at login is currently enabled.
    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Current status description.
    public var statusDescription: String {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                return "Enabled"
            case .requiresApproval:
                return "Requires Approval in System Settings"
            case .notFound:
                return "Not Found (App must be in Applications folder or signed bundle)"
            case .notRegistered:
                return "Not Registered"
            @unknown default:
                return "Unknown"
            }
        }
        return "Unsupported on this macOS version"
    }

    /// Enables or disables launch at login.
    public func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                do {
                    try SMAppService.mainApp.register()
                    logger.info("Successfully registered main app with SMAppService")
                } catch {
                    logger.error("Failed to register launch at login: \(error.localizedDescription)")
                    throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
                }
            } else {
                do {
                    try SMAppService.mainApp.unregister()
                    logger.info("Successfully unregistered main app from SMAppService")
                } catch {
                    logger.error("Failed to unregister launch at login: \(error.localizedDescription)")
                    throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
                }
            }
        }
    }
}

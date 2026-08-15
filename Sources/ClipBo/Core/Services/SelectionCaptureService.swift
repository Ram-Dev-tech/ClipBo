import Cocoa
import ApplicationServices
import OSLog

/// Result of a Quick Capture operation via Accessibility APIs.
public enum SelectionCaptureResult: Equatable, Sendable {
    /// Successfully captured selected text.
    case text(String)
    /// Successfully captured image data (PNG).
    case image(Data)
    /// The focused element had no selection, or nothing was accessible.
    case notFound
    /// Accessibility permission was not granted.
    case accessibilityDenied
}

/// Service to capture selected text and images from frontmost applications via macOS Accessibility APIs.
/// Never touches NSPasteboard — all reads are direct Accessibility API calls.
public final class SelectionCaptureService: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "SelectionCaptureService")
    
    public static let shared = SelectionCaptureService()

    public init() {}

    /// Checks whether the user has granted Accessibility permissions to ClipBo.
    public var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Logs diagnostic identity for troubleshooting TCC / code-signing permissions.
    public func logDiagnostics() {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let bundlePath = Bundle.main.bundlePath
        let isTrusted = AXIsProcessTrusted()
        let pid = ProcessInfo.processInfo.processIdentifier
        logger.info("Accessibility Diagnostics — BundleID: \(bundleId), Path: \(bundlePath), PID: \(pid), Trusted: \(isTrusted)")
    }

    /// Prompts the system permission dialog for Accessibility if not already granted.
    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        logDiagnostics()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Unified capture: attempts text first, then image, from the frontmost application's focused element.
    /// Never reads or writes NSPasteboard. Returns a typed result for safe handling.
    public func captureSelection() -> SelectionCaptureResult {
        guard isAccessibilityGranted else {
            logger.warning("Quick Capture aborted: Accessibility permission not granted.")
            return .accessibilityDenied
        }

        guard let axElement = resolvedFocusedElement() else {
            logger.warning("Quick Capture: No focused element found.")
            return .notFound
        }

        // 1. Try selected text first
        if let text = extractSelectedText(from: axElement) {
            logger.info("Quick Capture: Captured selected text (\(text.count) chars).")
            return .text(text)
        }

        // 2. Try image data from the focused element
        if let imageData = extractImageData(from: axElement) {
            logger.info("Quick Capture: Captured image data (\(imageData.count) bytes).")
            return .image(imageData)
        }

        logger.warning("Quick Capture: No selected text or image found in focused element.")
        return .notFound
    }

    /// Directly retrieves the selected text from the frontmost application's focused UI element without touching NSPasteboard.
    public func captureSelectedText() -> String? {
        logDiagnostics()
        guard isAccessibilityGranted else {
            logger.warning("Quick Capture aborted: AXIsProcessTrusted() returned false. Accessibility permission not granted.")
            return nil
        }

        logger.info("Quick Capture starting: Accessibility permission is granted.")

        // 1. Try via frontmost application's focused element
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let pid = frontApp.processIdentifier
            logger.info("Querying frontmost application: \(frontApp.localizedName ?? "Unknown") (PID: \(pid))")
            
            let appElement = AXUIElementCreateApplication(pid)
            var focusedElementValue: AnyObject?
            let appFocusResult = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElementValue
            )

            if appFocusResult == .success, let element = focusedElementValue {
                let axElement = element as! AXUIElement
                if let text = extractSelectedText(from: axElement) {
                    logger.info("Successfully captured selected text from frontmost app focused element (\(text.count) chars)")
                    return text
                }
            } else {
                logger.debug("Could not get focused element from application element (AXError: \(appFocusResult.rawValue))")
            }
        }

        // 2. Fallback: Query system-wide focused element
        logger.info("Querying system-wide focused element fallback")
        let systemWide = AXUIElementCreateSystemWide()
        var systemFocusedElementValue: AnyObject?
        let systemFocusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &systemFocusedElementValue
        )

        if systemFocusResult == .success, let element = systemFocusedElementValue {
            let axElement = element as! AXUIElement
            if let text = extractSelectedText(from: axElement) {
                logger.info("Successfully captured selected text from system-wide focused element (\(text.count) chars)")
                return text
            }
        } else {
            logger.debug("Could not get focused element from system-wide element (AXError: \(systemFocusResult.rawValue))")
        }

        logger.warning("Quick Capture completed: No selected text could be extracted from the focused element.")
        return nil
    }

    // MARK: - Private Helpers

    /// Resolves the best available focused AXUIElement from frontmost app or system-wide fallback.
    private func resolvedFocusedElement() -> AXUIElement? {
        // 1. Frontmost application focused element
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let pid = frontApp.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            var focusedValue: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
               let element = focusedValue {
                return (element as! AXUIElement)
            }
        }

        // 2. System-wide focused element fallback
        let systemWide = AXUIElementCreateSystemWide()
        var systemFocused: AnyObject?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &systemFocused) == .success,
           let element = systemFocused {
            return (element as! AXUIElement)
        }

        return nil
    }

    private func extractSelectedText(from axElement: AXUIElement) -> String? {
        // Direct selected text attribute
        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        if textResult == .success, let text = selectedTextValue as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return text
            }
        }

        // Check if value + selectedTextRange can extract the selection
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )

        if rangeResult == .success, let axValue = rangeValue as! AXValue? {
            var range = CFRange()
            if AXValueGetValue(axValue, .cfRange, &range), range.length > 0 {
                var fullTextValue: AnyObject?
                if AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &fullTextValue) == .success,
                   let fullText = fullTextValue as? String {
                    let utf16 = fullText.utf16
                    if range.location >= 0 && range.location + range.length <= utf16.count {
                        let start = utf16.index(utf16.startIndex, offsetBy: range.location)
                        let end = utf16.index(start, offsetBy: range.length)
                        let substring = String(fullText[start..<end])
                        if !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return substring
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Attempts to extract image data from an AXUIElement via kAXImageAttribute or kAXValueAttribute.
    /// Returns PNG data if successful, nil if the element does not expose image data.
    private func extractImageData(from axElement: AXUIElement) -> Data? {
        // Attempt kAXImageAttribute (may return NSImage on some elements/apps)
        var imageValue: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, "AXImage" as CFString, &imageValue) == .success,
           let nsImage = imageValue as? NSImage,
           let pngData = nsImage.pngData() {
            return pngData
        }

        // Attempt kAXValueAttribute when the role is AXImage
        var roleValue: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String, role == "AXImage" {
            var val: AnyObject?
            if AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &val) == .success,
               let nsImage = val as? NSImage,
               let pngData = nsImage.pngData() {
                return pngData
            }
        }

        return nil
    }
}

private extension NSImage {
    /// Returns PNG representation of the image, or nil if conversion fails.
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

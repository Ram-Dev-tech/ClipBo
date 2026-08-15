import Foundation

/// Pure protocol for evaluating pasteboard payloads into classified domain results.
public protocol ContentClassifierProtocol: Sendable {
    func classify(payload: PasteboardPayload) -> ClipClassification
}

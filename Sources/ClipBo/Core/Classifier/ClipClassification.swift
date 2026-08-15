import Foundation

/// Output of the classification engine representing the determined content type and extracted metadata.
public struct ClipClassification: Equatable, Sendable {
    public let type: ClipType
    public let confidence: Double
    public let detectedLanguage: String?
    public let urlDomain: String?
    public let colorHex: String?
    public let normalizedContent: String?
    public let customMetadata: [String: String]

    public init(
        type: ClipType,
        confidence: Double = 1.0,
        detectedLanguage: String? = nil,
        urlDomain: String? = nil,
        colorHex: String? = nil,
        normalizedContent: String? = nil,
        customMetadata: [String: String] = [:]
    ) {
        self.type = type
        self.confidence = confidence
        self.detectedLanguage = detectedLanguage
        self.urlDomain = urlDomain
        self.colorHex = colorHex
        self.normalizedContent = normalizedContent
        self.customMetadata = customMetadata
    }
}

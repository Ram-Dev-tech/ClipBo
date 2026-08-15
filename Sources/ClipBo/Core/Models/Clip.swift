import Foundation

/// Pure domain model representing a single clipboard entry.
public struct Clip: Identifiable, Equatable, Sendable, Codable, Hashable {
    public let id: UUID
    public var type: ClipType
    public var textContent: String?
    public var imagePath: String?
    public let createdAt: Date
    public var isStarred: Bool
    
    // Strongly typed metadata for classification and context
    public var sourceAppBundleId: String?
    public var sourceAppName: String?
    public var charCount: Int?
    public var wordCount: Int?
    public var imageWidth: Double?
    public var imageHeight: Double?
    
    // Collections and future taxonomy
    public var collectionIds: [UUID]
    
    // Extensible key-value metadata dictionary
    public var customMetadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: ClipType,
        textContent: String? = nil,
        imagePath: String? = nil,
        createdAt: Date = Date(),
        isStarred: Bool = false,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        charCount: Int? = nil,
        wordCount: Int? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        collectionIds: [UUID] = [],
        customMetadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.textContent = textContent
        self.imagePath = imagePath
        self.createdAt = createdAt
        self.isStarred = isStarred
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.charCount = charCount ?? textContent?.count
        self.wordCount = wordCount ?? textContent?.split(whereSeparator: \.isWhitespace).count
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.collectionIds = collectionIds
        self.customMetadata = customMetadata
    }

    /// Convenience factory for plain text clips
    public static func text(
        _ content: String,
        id: UUID = UUID(),
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil
    ) -> Clip {
        Clip(
            id: id,
            type: .text,
            textContent: content,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName
        )
    }

    /// Convenience factory for image clips
    public static func image(
        imagePath: String,
        id: UUID = UUID(),
        width: Double? = nil,
        height: Double? = nil,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil
    ) -> Clip {
        Clip(
            id: id,
            type: .image,
            imagePath: imagePath,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            imageWidth: width,
            imageHeight: height
        )
    }

    /// Convenience factory for URL clips
    public static func url(
        _ urlString: String,
        id: UUID = UUID(),
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil
    ) -> Clip {
        Clip(
            id: id,
            type: .url,
            textContent: urlString,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName
        )
    }
}

import Foundation
import AppKit

/// Parsed representation of extracted clipboard contents with advanced format metadata support.
public struct PasteboardPayload: Equatable, Sendable {
    public let type: ClipType
    public let textContent: String?
    public let imageData: Data?
    public let imageWidth: Double?
    public let imageHeight: Double?
    public let sourceAppBundleId: String?
    public let sourceAppName: String?
    public let detectedFormat: String?
    public let fileURL: URL?
    public let fileName: String?
    public let fileUTI: String?
    public let customMetadata: [String: String]

    public init(
        type: ClipType,
        textContent: String? = nil,
        imageData: Data? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        detectedFormat: String? = nil,
        fileURL: URL? = nil,
        fileName: String? = nil,
        fileUTI: String? = nil,
        customMetadata: [String: String] = [:]
    ) {
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.detectedFormat = detectedFormat
        self.fileURL = fileURL
        self.fileName = fileName
        self.fileUTI = fileUTI
        self.customMetadata = customMetadata
    }

    /// Factory for plain text payload
    public static func text(
        _ content: String,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        customMetadata: [String: String] = [:]
    ) -> PasteboardPayload {
        PasteboardPayload(
            type: .text,
            textContent: content,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            detectedFormat: "plainText",
            customMetadata: customMetadata
        )
    }

    /// Factory for URL payload
    public static func url(
        _ urlString: String,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        customMetadata: [String: String] = [:]
    ) -> PasteboardPayload {
        PasteboardPayload(
            type: .url,
            textContent: urlString,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            detectedFormat: "url",
            customMetadata: customMetadata
        )
    }

    /// Factory for image payload
    public static func image(
        data: Data,
        width: Double? = nil,
        height: Double? = nil,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        customMetadata: [String: String] = [:]
    ) -> PasteboardPayload {
        PasteboardPayload(
            type: .image,
            imageData: data,
            imageWidth: width,
            imageHeight: height,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            detectedFormat: "image",
            customMetadata: customMetadata
        )
    }

    /// Factory for normalized RTF payload
    public static func rtf(
        text: String,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        customMetadata: [String: String] = [:]
    ) -> PasteboardPayload {
        var meta = customMetadata
        meta["clipboardFormat"] = "rtf"
        return PasteboardPayload(
            type: .text,
            textContent: text,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            detectedFormat: "rtf",
            customMetadata: meta
        )
    }

    /// Factory for normalized HTML payload
    public static func html(
        text: String,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        customMetadata: [String: String] = [:]
    ) -> PasteboardPayload {
        var meta = customMetadata
        meta["clipboardFormat"] = "html"
        return PasteboardPayload(
            type: .text,
            textContent: text,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            detectedFormat: "html",
            customMetadata: meta
        )
    }

    /// Factory for Finder file reference payload
    public static func file(
        url: URL,
        fileName: String? = nil,
        fileUTI: String? = nil,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        customMetadata: [String: String] = [:]
    ) -> PasteboardPayload {
        let name = fileName ?? url.lastPathComponent
        var meta = customMetadata
        meta["isFileURL"] = "true"
        meta["fileURL"] = url.absoluteString
        meta["fileName"] = name
        meta["filePath"] = url.path
        if let uti = fileUTI {
            meta["fileUTI"] = uti
        }
        meta["clipboardFormat"] = "fileURL"

        return PasteboardPayload(
            type: .text,
            textContent: name,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            detectedFormat: "fileURL",
            fileURL: url,
            fileName: name,
            fileUTI: fileUTI,
            customMetadata: meta
        )
    }
}

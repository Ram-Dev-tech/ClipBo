import Foundation
import OSLog

public enum ImageStorageError: LocalizedError, Sendable {
    case directoryCreationFailed(String)
    case writeFailed(String)
    case fileNotFound(String)
    case invalidImageData

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let msg):
            return "Failed to create images directory: \(msg)"
        case .writeFailed(let msg):
            return "Failed to write image data to disk: \(msg)"
        case .fileNotFound(let path):
            return "Image file not found at: \(path)"
        case .invalidImageData:
            return "Provided image data is empty or invalid"
        }
    }
}

/// Manages disk-based persistence for image clips outside the database.
public final class ImageStorage: Sendable {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "ImageStorage")
    public let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("ClipBo", isDirectory: true).appendingPathComponent("Images", isDirectory: true)
        }
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            do {
                try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("Could not create ImageStorage directory at \(self.baseDirectory.path): \(error.localizedDescription)")
            }
        }
    }

    /// Saves raw image data to disk and returns the relative filename.
    @discardableResult
    public func saveImage(data: Data, id: UUID = UUID(), fileExtension: String = "png") throws -> String {
        guard !data.isEmpty else {
            throw ImageStorageError.invalidImageData
        }
        createDirectoryIfNeeded()
        let filename = "\(id.uuidString).\(fileExtension)"
        let fileURL = baseDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            logger.error("Failed to write image file: \(error.localizedDescription)")
            throw ImageStorageError.writeFailed(error.localizedDescription)
        }
    }

    /// Loads raw image data from disk given the relative filename or full path.
    public func loadImage(filenameOrPath: String) -> Data? {
        let fileURL: URL
        if filenameOrPath.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: filenameOrPath)
        } else {
            fileURL = baseDirectory.appendingPathComponent(filenameOrPath)
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.warning("Image file does not exist at \(fileURL.path)")
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    /// Deletes an image file given its relative filename or full path.
    public func deleteImage(filenameOrPath: String) throws {
        let fileURL: URL
        if filenameOrPath.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: filenameOrPath)
        } else {
            fileURL = baseDirectory.appendingPathComponent(filenameOrPath)
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logger.error("Failed to delete image at \(fileURL.path): \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Clears all files in the images directory.
    public func clearAllImages() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseDirectory.path) else { return }
        let fileURLs = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        for url in fileURLs {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Removes any image files from disk that are no longer referenced in CoreData.
    public func cleanupOrphanImages(validFilenames: Set<String>) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        var removedCount = 0
        for file in files {
            let filename = file.lastPathComponent
            if !validFilenames.contains(filename) {
                try? fileManager.removeItem(at: file)
                removedCount += 1
            }
        }
        if removedCount > 0 {
            logger.info("Cleaned up \(removedCount) orphaned image files.")
        }
    }

    /// Returns the full file URL for a given relative filename.
    public func fullURL(for filename: String) -> URL {
        baseDirectory.appendingPathComponent(filename)
    }

    /// Calculates total size of stored images on disk in bytes.
    public func imagesDirectorySize() -> Int64 {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Returns the count of image files stored on disk.
    public func imageCount() -> Int {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.count
    }
}

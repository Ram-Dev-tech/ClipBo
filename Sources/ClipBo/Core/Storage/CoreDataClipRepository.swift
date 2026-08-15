import Foundation
import CoreData
import OSLog

/// Native CoreData (Apple SQLite-backed) implementation of `ClipRepositoryProtocol`.
public actor CoreDataClipRepository: ClipRepositoryProtocol {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "CoreDataClipRepository")
    public let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init(inMemory: Bool = false) throws {
        let model = Self.createManagedObjectModel()
        let container = NSPersistentContainer(name: "ClipBo", managedObjectModel: model)
        
        let storeDescription = NSPersistentStoreDescription()
        if inMemory {
            storeDescription.type = NSInMemoryStoreType
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let clipBoDir = appSupport.appendingPathComponent("ClipBo", isDirectory: true)
            try? FileManager.default.createDirectory(at: clipBoDir, withIntermediateDirectories: true)
            let storeURL = clipBoDir.appendingPathComponent("ClipBo.sqlite")
            storeDescription.url = storeURL
            storeDescription.type = NSSQLiteStoreType
        }

        container.persistentStoreDescriptions = [storeDescription]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                loadError = error
            }
        }
        
        if let error = loadError {
            throw error
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        self.container = container
        self.context = container.newBackgroundContext()
    }

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "ClipEntity"
        entity.managedObjectClassName = "NSManagedObject"

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        let typeRawAttr = NSAttributeDescription()
        typeRawAttr.name = "typeRaw"
        typeRawAttr.attributeType = .stringAttributeType
        typeRawAttr.isOptional = false

        let textContentAttr = NSAttributeDescription()
        textContentAttr.name = "textContent"
        textContentAttr.attributeType = .stringAttributeType
        textContentAttr.isOptional = true

        let imagePathAttr = NSAttributeDescription()
        imagePathAttr.name = "imagePath"
        imagePathAttr.attributeType = .stringAttributeType
        imagePathAttr.isOptional = true

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false

        let isStarredAttr = NSAttributeDescription()
        isStarredAttr.name = "isStarred"
        isStarredAttr.attributeType = .booleanAttributeType
        isStarredAttr.defaultValue = false

        let sourceAppBundleIdAttr = NSAttributeDescription()
        sourceAppBundleIdAttr.name = "sourceAppBundleId"
        sourceAppBundleIdAttr.attributeType = .stringAttributeType
        sourceAppBundleIdAttr.isOptional = true

        let sourceAppNameAttr = NSAttributeDescription()
        sourceAppNameAttr.name = "sourceAppName"
        sourceAppNameAttr.attributeType = .stringAttributeType
        sourceAppNameAttr.isOptional = true

        let charCountAttr = NSAttributeDescription()
        charCountAttr.name = "charCount"
        charCountAttr.attributeType = .integer64AttributeType
        charCountAttr.isOptional = true

        let wordCountAttr = NSAttributeDescription()
        wordCountAttr.name = "wordCount"
        wordCountAttr.attributeType = .integer64AttributeType
        wordCountAttr.isOptional = true

        let imageWidthAttr = NSAttributeDescription()
        imageWidthAttr.name = "imageWidth"
        imageWidthAttr.attributeType = .doubleAttributeType
        imageWidthAttr.isOptional = true

        let imageHeightAttr = NSAttributeDescription()
        imageHeightAttr.name = "imageHeight"
        imageHeightAttr.attributeType = .doubleAttributeType
        imageHeightAttr.isOptional = true

        let collectionIdsJSONAttr = NSAttributeDescription()
        collectionIdsJSONAttr.name = "collectionIdsJSON"
        collectionIdsJSONAttr.attributeType = .stringAttributeType
        collectionIdsJSONAttr.isOptional = true

        let customMetadataJSONAttr = NSAttributeDescription()
        customMetadataJSONAttr.name = "customMetadataJSON"
        customMetadataJSONAttr.attributeType = .stringAttributeType
        customMetadataJSONAttr.isOptional = true

        entity.properties = [
            idAttr, typeRawAttr, textContentAttr, imagePathAttr,
            createdAtAttr, isStarredAttr, sourceAppBundleIdAttr, sourceAppNameAttr,
            charCountAttr, wordCountAttr, imageWidthAttr, imageHeightAttr,
            collectionIdsJSONAttr, customMetadataJSONAttr
        ]
        model.entities = [entity]
        return model
    }

    public func insert(_ clip: Clip) throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.predicate = NSPredicate(format: "id == %@", clip.id as CVarArg)
            request.fetchLimit = 1

            let object: NSManagedObject
            if let existing = try context.fetch(request).first {
                object = existing
            } else {
                object = NSEntityDescription.insertNewObject(forEntityName: "ClipEntity", into: context)
                object.setValue(clip.id, forKey: "id")
                object.setValue(clip.createdAt, forKey: "createdAt")
            }

            object.setValue(clip.type.rawValue, forKey: "typeRaw")
            object.setValue(clip.textContent, forKey: "textContent")
            object.setValue(clip.imagePath, forKey: "imagePath")
            object.setValue(clip.isStarred, forKey: "isStarred")
            object.setValue(clip.sourceAppBundleId, forKey: "sourceAppBundleId")
            object.setValue(clip.sourceAppName, forKey: "sourceAppName")
            object.setValue(clip.charCount.map { NSNumber(value: $0) }, forKey: "charCount")
            object.setValue(clip.wordCount.map { NSNumber(value: $0) }, forKey: "wordCount")
            object.setValue(clip.imageWidth.map { NSNumber(value: $0) }, forKey: "imageWidth")
            object.setValue(clip.imageHeight.map { NSNumber(value: $0) }, forKey: "imageHeight")

            if !clip.collectionIds.isEmpty, let data = try? JSONEncoder().encode(clip.collectionIds) {
                object.setValue(String(data: data, encoding: .utf8), forKey: "collectionIdsJSON")
            } else {
                object.setValue(nil, forKey: "collectionIdsJSON")
            }

            if !clip.customMetadata.isEmpty, let data = try? JSONEncoder().encode(clip.customMetadata) {
                object.setValue(String(data: data, encoding: .utf8), forKey: "customMetadataJSON")
            } else {
                object.setValue(nil, forKey: "customMetadataJSON")
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    public func fetchRecent(limit: Int = 100) throws -> [Clip] {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            if limit > 0 {
                request.fetchLimit = limit
            }

            let objects = try context.fetch(request)
            return objects.compactMap { self.mapObjectToClip($0) }
        }
    }

    public func fetch(byId id: UUID) throws -> Clip? {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            let objects = try context.fetch(request)
            return objects.first.flatMap { self.mapObjectToClip($0) }
        }
    }

    public func update(_ clip: Clip) throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.predicate = NSPredicate(format: "id == %@", clip.id as CVarArg)
            request.fetchLimit = 1

            guard let object = try context.fetch(request).first else {
                throw NSError(domain: "CoreDataClipRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Clip not found for update"])
            }

            object.setValue(clip.type.rawValue, forKey: "typeRaw")
            object.setValue(clip.textContent, forKey: "textContent")
            object.setValue(clip.imagePath, forKey: "imagePath")
            object.setValue(clip.isStarred, forKey: "isStarred")
            object.setValue(clip.sourceAppBundleId, forKey: "sourceAppBundleId")
            object.setValue(clip.sourceAppName, forKey: "sourceAppName")
            object.setValue(clip.charCount.map { NSNumber(value: $0) }, forKey: "charCount")
            object.setValue(clip.wordCount.map { NSNumber(value: $0) }, forKey: "wordCount")
            object.setValue(clip.imageWidth.map { NSNumber(value: $0) }, forKey: "imageWidth")
            object.setValue(clip.imageHeight.map { NSNumber(value: $0) }, forKey: "imageHeight")

            if !clip.collectionIds.isEmpty, let data = try? JSONEncoder().encode(clip.collectionIds) {
                object.setValue(String(data: data, encoding: .utf8), forKey: "collectionIdsJSON")
            } else {
                object.setValue(nil, forKey: "collectionIdsJSON")
            }

            if !clip.customMetadata.isEmpty, let data = try? JSONEncoder().encode(clip.customMetadata) {
                object.setValue(String(data: data, encoding: .utf8), forKey: "customMetadataJSON")
            } else {
                object.setValue(nil, forKey: "customMetadataJSON")
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    public func delete(byId id: UUID) throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            if let object = try context.fetch(request).first {
                context.delete(object)
                if context.hasChanges {
                    try context.save()
                }
            }
        }
    }

    public func clearAll() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            let objects = try context.fetch(request)
            for obj in objects {
                context.delete(obj)
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    public func count() throws -> Int {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            return try context.count(for: request)
        }
    }

    /// Enforces history retention policy by pruning non-starred clips based on maximum count and/or age.
    /// Starred clips (isStarred == true) are strictly protected and never pruned automatically.
    public func enforceRetentionLimit(maxNonStarred: Int, maxAgeDays: Int = 0) throws {
        try context.performAndWait {
            var prunedCount = 0

            // 1. Enforce Maximum Age Limit (if > 0)
            if maxAgeDays > 0 {
                let cutoffDate = Date().addingTimeInterval(-Double(maxAgeDays) * 86400.0)
                let ageRequest = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
                ageRequest.predicate = NSPredicate(format: "isStarred == NO AND createdAt < %@", cutoffDate as NSDate)
                
                let expiredClips = try context.fetch(ageRequest)
                for obj in expiredClips {
                    context.delete(obj)
                    prunedCount += 1
                }
            }

            // 2. Enforce Maximum Non-Starred Count Limit (if > 0)
            if maxNonStarred > 0 {
                let countRequest = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
                countRequest.predicate = NSPredicate(format: "isStarred == NO")
                let nonStarredCount = try context.count(for: countRequest)

                if nonStarredCount > maxNonStarred {
                    let excess = nonStarredCount - maxNonStarred
                    let deleteRequest = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
                    deleteRequest.predicate = NSPredicate(format: "isStarred == NO")
                    deleteRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)] // Oldest first
                    deleteRequest.fetchLimit = excess

                    let toDelete = try context.fetch(deleteRequest)
                    for obj in toDelete {
                        context.delete(obj)
                        prunedCount += 1
                    }
                }
            }

            if context.hasChanges {
                try context.save()
                logger.info("Enforced retention policy: pruned \(prunedCount) non-starred clips (limit: \(maxNonStarred), maxAgeDays: \(maxAgeDays))")
            }
        }
    }

    /// Calculates total SQLite database file size in bytes (main db + wal + shm).
    public nonisolated func databaseFileSize() -> Int64 {
        sqliteFileSize() + walFileSize() + shmFileSize()
    }

    /// Calculates the main .sqlite file size in bytes.
    public nonisolated func sqliteFileSize() -> Int64 {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("ClipBo/ClipBo.sqlite")
        return (try? FileManager.default.attributesOfItem(atPath: storeURL.path)[.size] as? Int64) ?? 0
    }

    /// Calculates the .sqlite-wal write-ahead log file size in bytes.
    public nonisolated func walFileSize() -> Int64 {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let walURL = appSupport.appendingPathComponent("ClipBo/ClipBo.sqlite-wal")
        return (try? FileManager.default.attributesOfItem(atPath: walURL.path)[.size] as? Int64) ?? 0
    }

    /// Calculates the .sqlite-shm shared memory file size in bytes.
    public nonisolated func shmFileSize() -> Int64 {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let shmURL = appSupport.appendingPathComponent("ClipBo/ClipBo.sqlite-shm")
        return (try? FileManager.default.attributesOfItem(atPath: shmURL.path)[.size] as? Int64) ?? 0
    }

    /// Returns all image filenames currently referenced by clips.
    public func fetchAllImagePaths() throws -> [String] {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.predicate = NSPredicate(format: "imagePath != nil")
            let objects = try context.fetch(request)
            return objects.compactMap { $0.value(forKey: "imagePath") as? String }
        }
    }

    private nonisolated func mapObjectToClip(_ object: NSManagedObject) -> Clip? {
        guard let id = object.value(forKey: "id") as? UUID,
              let typeRaw = object.value(forKey: "typeRaw") as? String,
              let createdAt = object.value(forKey: "createdAt") as? Date else {
            return nil
        }

        let type = ClipType(rawValue: typeRaw) ?? .text
        let textContent = object.value(forKey: "textContent") as? String
        let imagePath = object.value(forKey: "imagePath") as? String
        let isStarred = object.value(forKey: "isStarred") as? Bool ?? false
        let sourceAppBundleId = object.value(forKey: "sourceAppBundleId") as? String
        let sourceAppName = object.value(forKey: "sourceAppName") as? String
        let charCount = (object.value(forKey: "charCount") as? NSNumber)?.intValue
        let wordCount = (object.value(forKey: "wordCount") as? NSNumber)?.intValue
        let imageWidth = (object.value(forKey: "imageWidth") as? NSNumber)?.doubleValue
        let imageHeight = (object.value(forKey: "imageHeight") as? NSNumber)?.doubleValue

        var collectionIds: [UUID] = []
        if let json = object.value(forKey: "collectionIdsJSON") as? String,
           let data = json.data(using: .utf8) {
            collectionIds = (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }

        var customMetadata: [String: String] = [:]
        if let json = object.value(forKey: "customMetadataJSON") as? String,
           let data = json.data(using: .utf8) {
            customMetadata = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }

        return Clip(
            id: id,
            type: type,
            textContent: textContent,
            imagePath: imagePath,
            createdAt: createdAt,
            isStarred: isStarred,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            charCount: charCount,
            wordCount: wordCount,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            collectionIds: collectionIds,
            customMetadata: customMetadata
        )
    }
}

import Foundation
import CoreData
import ClipBo

public struct CoreDataClipRepositoryTests {
    public static func runAll() async throws {
        print("  ▶ Running CoreDataClipRepositoryTests...")
        try await testInsertAndFetchRecent()
        try await testFetchById()
        try await testUpdateClip()
        try await testDeleteClip()
        try await testClearAll()
        print("  ✔ CoreDataClipRepositoryTests passed")
    }

    static func testInsertAndFetchRecent() async throws {
        let repository = try CoreDataClipRepository(inMemory: true)
        let clip1 = Clip.text("First clip")
        let clip2 = Clip.text("Second clip")

        try await repository.insert(clip1)
        try await repository.insert(clip2)

        let clips = try await repository.fetchRecent(limit: 10)
        try assertEqual(clips.count, 2)
        try assertEqual(try await repository.count(), 2)
    }

    static func testFetchById() async throws {
        let repository = try CoreDataClipRepository(inMemory: true)
        let targetId = UUID()
        let clip = Clip(id: targetId, type: .text, textContent: "Find me")

        try await repository.insert(clip)

        let found = try await repository.fetch(byId: targetId)
        try assertNotNil(found)
        try assertEqual(found?.textContent, "Find me")

        let notFound = try await repository.fetch(byId: UUID())
        try assertNil(notFound)
    }

    static func testUpdateClip() async throws {
        let repository = try CoreDataClipRepository(inMemory: true)
        let clip = Clip.text("Initial text")
        try await repository.insert(clip)

        var modified = clip
        modified.isStarred = true
        modified.textContent = "Updated text"
        try await repository.update(modified)

        let fetched = try await repository.fetch(byId: clip.id)
        try assertEqual(fetched?.isStarred, true)
        try assertEqual(fetched?.textContent, "Updated text")
    }

    static func testDeleteClip() async throws {
        let repository = try CoreDataClipRepository(inMemory: true)
        let clip = Clip.text("To be deleted")
        try await repository.insert(clip)
        try assertEqual(try await repository.count(), 1)

        try await repository.delete(byId: clip.id)
        try assertEqual(try await repository.count(), 0)
    }

    static func testClearAll() async throws {
        let repository = try CoreDataClipRepository(inMemory: true)
        try await repository.insert(Clip.text("1"))
        try await repository.insert(Clip.text("2"))
        try await repository.insert(Clip.text("3"))
        try assertEqual(try await repository.count(), 3)

        try await repository.clearAll()
        try assertEqual(try await repository.count(), 0)
    }
}

import Foundation
import ClipBo

public struct CategoryFilterTests {
    @MainActor
    public static func runAll() async throws {
        print("  ▶ Running CategoryFilterTests...")
        try testCategoryMatching()
        try testEmojiCategoryMatching()
        try testCategoryCyclicNavigation()
        try await testCoordinatorFiltering()
        try testCategoryManagementService()
        print("  ✔ CategoryFilterTests passed")
    }

    static func testCategoryMatching() throws {
        let textClip = Clip.text("Plain text sample")
        let urlClip = Clip.url("https://apple.com")
        let codeClip = Clip(type: .code, textContent: "func test() {}")
        let imageClip = Clip.image(imagePath: "pic.png")
        var starredClip = Clip.text("Starred note")
        starredClip.isStarred = true

        // Category .all matches everything
        try assertTrue(ClipCategory.all.matches(clip: textClip))
        try assertTrue(ClipCategory.all.matches(clip: urlClip))
        try assertTrue(ClipCategory.all.matches(clip: codeClip))
        try assertTrue(ClipCategory.all.matches(clip: imageClip))

        // Category .text
        try assertTrue(ClipCategory.text.matches(clip: textClip))
        try assertFalse(ClipCategory.text.matches(clip: urlClip))
        try assertFalse(ClipCategory.text.matches(clip: imageClip))

        // Category .url
        try assertTrue(ClipCategory.url.matches(clip: urlClip))
        try assertFalse(ClipCategory.url.matches(clip: textClip))

        // Category .code
        try assertTrue(ClipCategory.code.matches(clip: codeClip))
        try assertFalse(ClipCategory.code.matches(clip: textClip))

        // Category .images
        try assertTrue(ClipCategory.images.matches(clip: imageClip))
        try assertFalse(ClipCategory.images.matches(clip: textClip))

        // Category .star
        try assertTrue(ClipCategory.star.matches(clip: starredClip))
        try assertFalse(ClipCategory.star.matches(clip: textClip))
    }

    static func testEmojiCategoryMatching() throws {
        var emojiClip = Clip.text("😀😂🔥")
        emojiClip.customMetadata["isEmoji"] = "true"

        let plainTextClip = Clip.text("Ordinary sentence without emoji")
        let sentenceWithEmoji = Clip.text("Hello 😀")

        try assertTrue(ClipCategory.emoji.matches(clip: emojiClip))
        try assertFalse(ClipCategory.emoji.matches(clip: plainTextClip))
        try assertFalse(ClipCategory.emoji.matches(clip: sentenceWithEmoji))
    }

    static func testCategoryCyclicNavigation() throws {
        try assertEqual(ClipCategory.all.next(), .text)
        try assertEqual(ClipCategory.text.next(), .star)
        try assertEqual(ClipCategory.images.next(), .emoji)
        try assertEqual(ClipCategory.emoji.next(), .collections)
        try assertEqual(ClipCategory.collections.next(), .all)

        try assertEqual(ClipCategory.all.previous(), .collections)
        try assertEqual(ClipCategory.collections.previous(), .emoji)
        try assertEqual(ClipCategory.text.previous(), .all)
    }

    @MainActor
    static func testCoordinatorFiltering() async throws {
        let repo = try CoreDataClipRepository(inMemory: true)
        let coordinator = AppCoordinator(repository: repo)

        await coordinator.handleNewPayload(PasteboardPayload.text("Meeting agenda notes", sourceAppName: "Notes"))
        await coordinator.handleNewPayload(PasteboardPayload.url("https://github.com/apple/swift", sourceAppName: "Safari"))
        await coordinator.handleNewPayload(PasteboardPayload.text("🚀🔥🎉", sourceAppName: "Messages"))

        // Test search matching
        let searchResults = coordinator.filteredClips(category: .all, searchQuery: "agenda")
        try assertEqual(searchResults.count, 1)
        try assertEqual(searchResults.first?.textContent, "Meeting agenda notes")

        // Test category filtering
        let urlResults = coordinator.filteredClips(category: .url, searchQuery: "")
        try assertEqual(urlResults.count, 1)
        try assertEqual(urlResults.first?.type, .url)

        let emojiResults = coordinator.filteredClips(category: .emoji, searchQuery: "")
        try assertEqual(emojiResults.count, 1)
        try assertEqual(emojiResults.first?.textContent, "🚀🔥🎉")
    }

    @MainActor
    static func testCategoryManagementService() throws {
        let testDefaults = UserDefaults(suiteName: "com.clipbo.test.categories.\(UUID().uuidString)")!
        let service = SettingsService(userDefaults: testDefaults)

        let initialCategories = service.allCategories()
        try assertTrue(initialCategories.contains(where: { $0.id == "emoji" }))
        try assertTrue(initialCategories.contains(where: { $0.id == "all" }))

        // 1. Add Custom Category
        let workCat = service.addCustomCategory(title: "Work", iconName: "briefcase")
        try assertEqual(workCat.title, "Work")
        try assertEqual(workCat.iconName, "briefcase")
        try assertFalse(workCat.isBuiltIn)

        // 2. Rename Custom Category
        service.renameCategory(id: workCat.id, newTitle: "College")
        let updatedCat = service.allCategories().first(where: { $0.id == workCat.id })
        try assertEqual(updatedCat?.title, "College")

        // 3. Toggle Visibility
        service.toggleCategoryEnabled(id: workCat.id)
        let activeCats = service.activeCategories()
        try assertFalse(activeCats.contains(where: { $0.id == workCat.id }))

        service.toggleCategoryEnabled(id: workCat.id)
        let reEnabledCats = service.activeCategories()
        try assertTrue(reEnabledCats.contains(where: { $0.id == workCat.id }))

        // 4. Move / Reorder Category
        let orderBefore = service.allCategories().map { $0.id }
        service.moveCategory(id: workCat.id, direction: -1)
        let orderAfter = service.allCategories().map { $0.id }
        try assertTrue(orderBefore != orderAfter)

        // 5. Delete Custom Category
        let deleted = service.deleteCustomCategory(id: workCat.id)
        try assertTrue(deleted)
        try assertFalse(service.allCategories().contains(where: { $0.id == workCat.id }))

        // 6. Protect Built-in Category from Deletion
        let deleteBuiltIn = service.deleteCustomCategory(id: "all")
        try assertFalse(deleteBuiltIn)
        try assertTrue(service.allCategories().contains(where: { $0.id == "all" }))
    }
}

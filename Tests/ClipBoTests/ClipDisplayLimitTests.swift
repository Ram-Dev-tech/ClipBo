import Foundation
import ClipBo

public struct ClipDisplayLimitTests {
    @MainActor
    public static func runAll() async {
        print("  ▶ Running ClipDisplayLimitTests...")

        let repo = try! CoreDataClipRepository(inMemory: true)
        let imgStorage = ImageStorage()
        let coordinator = AppCoordinator(repository: repo, imageStorage: imgStorage)

        // 1. Constants verification
        print("    ▶ Testing ClipDisplayLimits constants...")
        assert(ClipDisplayLimits.all == 30, "ClipDisplayLimits.all must equal 30")
        assert(ClipDisplayLimits.perCategory == 20, "ClipDisplayLimits.perCategory must equal 20")
        assert(ClipDisplayLimits.limit(for: .all) == 30, "Limit for .all must be 30")
        assert(ClipDisplayLimits.limit(for: .text) == 20, "Limit for .text must be 20")
        assert(ClipDisplayLimits.limit(for: .code) == 20, "Limit for .code must be 20")
        assert(ClipDisplayLimits.limit(for: .prompt) == 20, "Limit for .prompt must be 20")
        assert(ClipDisplayLimits.limit(for: .url) == 20, "Limit for .url must be 20")
        assert(ClipDisplayLimits.limit(for: .images) == 20, "Limit for .images must be 20")
        assert(ClipDisplayLimits.limit(for: .emoji) == 20, "Limit for .emoji must be 20")
        assert(ClipDisplayLimits.limit(for: .star) == 20, "Limit for .star must be 20")
        assert(ClipDisplayLimits.limit(for: .collections) == 20, "Limit for .collections must be 20")
        print("      ✔ ClipDisplayLimits constants verified")

        // 2. Populate repository with large volume of distinct clip types
        // - 50 Text clips
        // - 50 Code clips
        // - 35 Prompt clips
        // - 30 URL clips
        // - 100 Image clips
        // - 25 Emoji clips
        print("    ▶ Populating test clips across categories...")
        var allInsertedClips: [Clip] = []

        // Text clips
        for i in 1...50 {
            let clip = Clip(
                id: UUID(),
                type: .text,
                textContent: "Plain text note number \(i)",
                createdAt: Date().addingTimeInterval(Double(-5000 + i)),
                isStarred: i <= 10
            )
            allInsertedClips.append(clip)
            try! await repo.insert(clip)
        }

        // Code clips
        for i in 1...50 {
            let clip = Clip(
                id: UUID(),
                type: .code,
                textContent: "func computeItem\(i)() -> Int { return \(i) * 2 }",
                createdAt: Date().addingTimeInterval(Double(-4000 + i)),
                isStarred: i <= 5
            )
            allInsertedClips.append(clip)
            try! await repo.insert(clip)
        }

        // Prompt clips
        for i in 1...35 {
            let clip = Clip(
                id: UUID(),
                type: .prompt,
                textContent: "Act as an expert prompt engineer and generate template \(i)",
                createdAt: Date().addingTimeInterval(Double(-3000 + i))
            )
            allInsertedClips.append(clip)
            try! await repo.insert(clip)
        }

        // URL clips
        for i in 1...30 {
            let clip = Clip(
                id: UUID(),
                type: .url,
                textContent: "https://example.com/resource/\(i)",
                createdAt: Date().addingTimeInterval(Double(-2000 + i)),
                customMetadata: ["urlDomain": "example.com"]
            )
            allInsertedClips.append(clip)
            try! await repo.insert(clip)
        }

        // Image clips (100 images)
        for i in 1...100 {
            let clip = Clip(
                id: UUID(),
                type: .image,
                imagePath: "test_image_\(i).png",
                createdAt: Date().addingTimeInterval(Double(-1000 + i)),
                sourceAppName: "Photoshop"
            )
            allInsertedClips.append(clip)
            try! await repo.insert(clip)
        }

        // Emoji clips
        for i in 1...25 {
            let clip = Clip(
                id: UUID(),
                type: .text,
                textContent: "🎉✨🚀",
                createdAt: Date().addingTimeInterval(Double(-500 + i)),
                customMetadata: ["isEmoji": "true"]
            )
            allInsertedClips.append(clip)
            try! await repo.insert(clip)
        }

        // Load all into AppCoordinator
        await coordinator.reloadRecentClips(limit: 1000)

        // 3. Test All Category limit = 30
        print("    ▶ Testing All category returns maximum 30 clips...")
        let allResults = coordinator.filteredClips(category: .all)
        assert(allResults.count == 30, "All category must return exactly 30 clips, got \(allResults.count)")
        print("      ✔ All category returns maximum 30 clips")

        // 4. Test Text Category limit = 20
        print("    ▶ Testing Text category returns maximum 20 clips...")
        let textResults = coordinator.filteredClips(category: .text)
        assert(textResults.count == 20, "Text category must return exactly 20 clips, got \(textResults.count)")
        assert(textResults.allSatisfy { $0.type == .text }, "All results in Text category must be text clips")
        print("      ✔ Text category returns maximum 20 clips")

        // 5. Test Code Category limit = 20
        print("    ▶ Testing Code category returns maximum 20 clips...")
        let codeResults = coordinator.filteredClips(category: .code)
        assert(codeResults.count == 20, "Code category must return exactly 20 clips, got \(codeResults.count)")
        assert(codeResults.allSatisfy { $0.type == .code }, "All results in Code category must be code clips")
        print("      ✔ Code category returns maximum 20 clips")

        // 6. Test Prompt Category limit = 20
        print("    ▶ Testing Prompt category returns maximum 20 clips...")
        let promptResults = coordinator.filteredClips(category: .prompt)
        assert(promptResults.count == 20, "Prompt category must return exactly 20 clips, got \(promptResults.count)")
        assert(promptResults.allSatisfy { $0.type == .prompt }, "All results in Prompt category must be prompt clips")
        print("      ✔ Prompt category returns maximum 20 clips")

        // 7. Test URL Category limit = 20
        print("    ▶ Testing URL category returns maximum 20 clips...")
        let urlResults = coordinator.filteredClips(category: .url)
        assert(urlResults.count == 20, "URL category must return exactly 20 clips, got \(urlResults.count)")
        assert(urlResults.allSatisfy { $0.type == .url }, "All results in URL category must be URL clips")
        print("      ✔ URL category returns maximum 20 clips")

        // 8. Test Images Category limit = 20 from 100+ stored images
        print("    ▶ Testing Images category returns maximum 20 clips from 100+ stored images...")
        let imageResults = coordinator.filteredClips(category: .images)
        assert(imageResults.count == 20, "Images category must return exactly 20 clips, got \(imageResults.count)")
        assert(imageResults.allSatisfy { $0.type == .image }, "All results in Images category must be image clips")
        print("      ✔ 100+ stored images still leave 20 available in Images category")

        // 9. Test Emoji Category limit = 20
        print("    ▶ Testing Emoji category returns maximum 20 clips...")
        let emojiResults = coordinator.filteredClips(category: .emoji)
        assert(emojiResults.count == 20, "Emoji category must return exactly 20 clips, got \(emojiResults.count)")
        print("      ✔ Emoji category returns maximum 20 clips")

        // 10. Test Star Category limit = 20
        print("    ▶ Testing Star category returns matching starred clips (up to 20)...")
        let starResults = coordinator.filteredClips(category: .star)
        assert(starResults.count == 15, "Star category should return all 15 starred clips (within 20 limit), got \(starResults.count)")
        assert(starResults.allSatisfy { $0.isStarred }, "All results in Star category must be starred")
        print("      ✔ Star category returns up to 20 starred clips")

        // 11. Test Search results limited AFTER filtering and ranking
        print("    ▶ Testing Search ranking happens BEFORE limiting...")
        // Ingest a very specific match created in the past, and 25 generic matches created recently
        let specificOld = Clip(
            id: UUID(),
            type: .code,
            textContent: "exactTargetUniqueFunction",
            createdAt: Date().addingTimeInterval(-10000)
        )
        try! await repo.insert(specificOld)
        for i in 1...25 {
            let generic = Clip(
                id: UUID(),
                type: .code,
                textContent: "func otherGenericItem\(i)() { let x = \(i) /* substring exactTargetUniqueFunction */ }",
                createdAt: Date().addingTimeInterval(Double(-100 + i))
            )
            try! await repo.insert(generic)
        }
        await coordinator.reloadRecentClips(limit: 1000)

        let searchMatches = coordinator.filteredClips(category: .code, searchQuery: "exactTargetUniqueFunction")
        assert(searchMatches.count == 20, "Search in Code category must return maximum 20 results, got \(searchMatches.count)")
        // The highest-ranked exact match must be the first result, even though it was created much earlier
        assert(searchMatches.first?.textContent == "exactTargetUniqueFunction",
               "Smart ranking must place highest relevance match at the top BEFORE 20-limit truncation")
        print("      ✔ Search relevance ranking happens BEFORE display limiting")

        // 12. Stored clips verification: retention not affected by display limits
        print("    ▶ Verifying database clips were NOT deleted by display limits...")
        let allInRepo = try! await repo.fetchRecent(limit: 1000)
        assert(allInRepo.count >= 290, "Database must still contain all inserted clips (got \(allInRepo.count)), zero clips deleted")
        print("      ✔ Display limits do not delete clips from storage")

        print("  ✔ ClipDisplayLimitTests passed")
    }
}

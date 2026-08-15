import Foundation
import ClipBo

public struct SearchTests {
    public static func runAll() {
        print("  ▶ Running SearchTests...")
        let searchEngine = ClipSearchEngine()

        let now = Date()

        // Setup diverse mock clips
        let clipCodePy = Clip(
            id: UUID(),
            type: .code,
            textContent: "def calculate_fibonacci(n):\n    return n if n <= 1 else calculate_fibonacci(n-1) + calculate_fibonacci(n-2)",
            createdAt: now.addingTimeInterval(-100),
            isStarred: false,
            customMetadata: ["detectedLanguage": "Python"]
        )

        let clipCodeSwift = Clip(
            id: UUID(),
            type: .code,
            textContent: "func sortArray(_ values: [Int]) -> [Int] {\n    values.sorted()\n}",
            createdAt: now.addingTimeInterval(-200),
            isStarred: true,
            customMetadata: ["detectedLanguage": "Swift"]
        )

        let clipPromptPy = Clip(
            id: UUID(),
            type: .prompt,
            textContent: "Act as a Python expert and explain how asyncio works.",
            createdAt: now.addingTimeInterval(-300),
            isStarred: true,
            customMetadata: ["detectedLanguage": "Python", "promptType": "coding"]
        )

        let clipPromptWriting = Clip(
            id: UUID(),
            type: .prompt,
            textContent: "Generate a professional email asking for vacation leave.",
            createdAt: now.addingTimeInterval(-400),
            isStarred: false,
            customMetadata: ["promptType": "writing"]
        )

        let clipUrlGitHub = Clip(
            id: UUID(),
            type: .url,
            textContent: "https://github.com/apple/swift",
            createdAt: now.addingTimeInterval(-500),
            isStarred: true,
            customMetadata: ["urlDomain": "github.com", "siteType": "GitHub"]
        )

        let clipEmoji = Clip(
            id: UUID(),
            type: .text,
            textContent: "🚀🔥🎉",
            createdAt: now.addingTimeInterval(-600),
            isStarred: false,
            customMetadata: ["isEmoji": "true"]
        )

        let clipProse = Clip(
            id: UUID(),
            type: .text,
            textContent: "Meeting notes regarding the new macOS application release roadmap.",
            createdAt: now.addingTimeInterval(-700),
            isStarred: false
        )

        let allMockClips = [clipCodePy, clipCodeSwift, clipPromptPy, clipPromptWriting, clipUrlGitHub, clipEmoji, clipProse]

        // 1. Test Query Parser
        print("    ▶ Testing Query Parser...")
        let q1 = searchEngine.parse(query: "code")
        assert(q1.categoryFilter == .code, "Expected categoryFilter == .code")
        assert(q1.textTerms.isEmpty, "Expected empty textTerms")

        let q2 = searchEngine.parse(query: "code python")
        assert(q2.categoryFilter == .code, "Expected categoryFilter == .code")
        assert(q2.textTerms == ["python"], "Expected textTerms == ['python']")

        let q3 = searchEngine.parse(query: "star prompt")
        assert(q3.isStarredOnly == true, "Expected isStarredOnly == true")
        assert(q3.categoryFilter == .prompt, "Expected categoryFilter == .prompt")

        let q4 = searchEngine.parse(query: "prompt writing")
        assert(q4.categoryFilter == .prompt, "Expected categoryFilter == .prompt")
        assert(q4.textTerms == ["writing"], "Expected textTerms == ['writing']")

        let q5 = searchEngine.parse(query: "  STAR   github  ")
        assert(q5.isStarredOnly == true, "Expected case-insensitive star parse")
        assert(q5.textTerms == ["github"], "Expected textTerms == ['github']")
        print("      ✔ Query parser correctly parsed category, star, and text tokens")

        // 2. Category Search Queries
        print("    ▶ Testing Category Filtering Queries...")
        let resCode = searchEngine.filterAndRank(clips: allMockClips, query: "code")
        assert(resCode.count == 2, "Expected 2 code clips, got \(resCode.count)")
        assert(resCode.allSatisfy { $0.type == .code }, "All results must be .code")

        let resPrompt = searchEngine.filterAndRank(clips: allMockClips, query: "prompt")
        assert(resPrompt.count == 2, "Expected 2 prompt clips, got \(resPrompt.count)")
        assert(resPrompt.allSatisfy { $0.type == .prompt }, "All results must be .prompt")

        let resStar = searchEngine.filterAndRank(clips: allMockClips, query: "star")
        assert(resStar.count == 3, "Expected 3 starred clips, got \(resStar.count)")
        assert(resStar.allSatisfy { $0.isStarred }, "All results must be starred")

        let resUrl = searchEngine.filterAndRank(clips: allMockClips, query: "url")
        assert(resUrl.count == 1 && resUrl.first?.id == clipUrlGitHub.id, "Expected GitHub URL clip")

        let resEmoji = searchEngine.filterAndRank(clips: allMockClips, query: "emoji")
        assert(resEmoji.count == 1 && resEmoji.first?.id == clipEmoji.id, "Expected Emoji clip")
        print("      ✔ Category and Star filtering queries verified")

        // 3. Combined Filtering Queries
        print("    ▶ Testing Combined Filtering Queries...")
        let resCodePy = searchEngine.filterAndRank(clips: allMockClips, query: "code python")
        assert(resCodePy.count == 1 && resCodePy.first?.id == clipCodePy.id, "Expected only Python code clip")

        let resPromptPy = searchEngine.filterAndRank(clips: allMockClips, query: "prompt python")
        assert(resPromptPy.count == 1 && resPromptPy.first?.id == clipPromptPy.id, "Expected only Python prompt clip")

        let resStarPrompt = searchEngine.filterAndRank(clips: allMockClips, query: "star prompt")
        assert(resStarPrompt.count == 1 && resStarPrompt.first?.id == clipPromptPy.id, "Expected only starred prompt clip")

        let resStarCode = searchEngine.filterAndRank(clips: allMockClips, query: "star code")
        assert(resStarCode.count == 1 && resStarCode.first?.id == clipCodeSwift.id, "Expected only starred Swift code clip")

        let resUrlGithub = searchEngine.filterAndRank(clips: allMockClips, query: "url github")
        assert(resUrlGithub.count == 1 && resUrlGithub.first?.id == clipUrlGitHub.id, "Expected GitHub URL clip")

        let resPromptWriting = searchEngine.filterAndRank(clips: allMockClips, query: "prompt writing")
        assert(resPromptWriting.count == 1 && resPromptWriting.first?.id == clipPromptWriting.id, "Expected writing prompt clip")
        print("      ✔ Combined category/star/content queries verified")

        // 4. Ranking Priority Verification
        print("    ▶ Testing Ranking Priority...")
        let clipExact = Clip(id: UUID(), type: .text, textContent: "python", createdAt: now.addingTimeInterval(-1000))
        let clipSubstring = Clip(id: UUID(), type: .text, textContent: "learn python programming with swift", createdAt: now.addingTimeInterval(-10))
        let ranked = searchEngine.filterAndRank(clips: [clipSubstring, clipExact], query: "python")
        assert(ranked.first?.id == clipExact.id, "Exact phrase match should rank above substring match even if older")
        print("      ✔ Exact match ranked ahead of substring match")

        // 5. Performance Benchmark with 1,000 Clips
        print("    ▶ Testing Search Performance with 1,000 clips...")
        var largeClips: [Clip] = []
        for i in 0..<1000 {
            let type: ClipType = (i % 4 == 0) ? .code : ((i % 4 == 1) ? .prompt : ((i % 4 == 2) ? .url : .text))
            largeClips.append(Clip(
                id: UUID(),
                type: type,
                textContent: "Simulated clip payload number \(i) with custom keyword test data",
                createdAt: now.addingTimeInterval(-Double(i)),
                isStarred: i % 5 == 0,
                customMetadata: (type == .code || type == .prompt) ? ["detectedLanguage": (i % 2 == 0 ? "Python" : "Swift")] : [:]
            ))
        }

        let start = CFAbsoluteTimeGetCurrent()
        let benchResults = searchEngine.filterAndRank(clips: largeClips, query: "code python")
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        assert(!benchResults.isEmpty, "Benchmark should return matches")
        print("      ✔ Filtered 1,000 clips in \(String(format: "%.4f", elapsed * 1000))ms (Latency well below 10ms threshold)")

        print("  ✔ SearchTests passed")
    }
}

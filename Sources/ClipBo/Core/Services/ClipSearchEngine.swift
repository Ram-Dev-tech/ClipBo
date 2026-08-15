import Foundation

/// Parsed search query model containing deterministic filters and text terms.
public struct ParsedSearchQuery: Equatable, Sendable {
    public let rawQuery: String
    public let categoryFilter: ClipCategory?
    public let isStarredOnly: Bool
    public let customCategoryName: String?
    public let textTerms: [String]

    public var isEmpty: Bool {
        rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasFiltersOnly: Bool {
        !isEmpty && textTerms.isEmpty && (categoryFilter != nil || isStarredOnly || customCategoryName != nil)
    }
}

/// Universal, deterministic, offline search engine for ClipBo supporting combined category, star, metadata, and full-text queries with smart local ranking.
public final class ClipSearchEngine: Sendable {
    public static let shared = ClipSearchEngine()

    public init() {}

    /// Parses a raw user search query string into structured category/star filters and text terms.
    public func parse(query: String, customCategoryNames: [String] = []) -> ParsedSearchQuery {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return ParsedSearchQuery(
                rawQuery: "",
                categoryFilter: nil,
                isStarredOnly: false,
                customCategoryName: nil,
                textTerms: []
            )
        }

        let tokens = clean.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else {
            return ParsedSearchQuery(
                rawQuery: clean,
                categoryFilter: nil,
                isStarredOnly: false,
                customCategoryName: nil,
                textTerms: []
            )
        }

        var categoryFilter: ClipCategory? = nil
        var isStarredOnly = false
        var customCategoryName: String? = nil
        var remainingTokens: [String] = []

        for token in tokens {
            let lower = token.lowercased()

            // 1. Star Alias Check
            if lower == "star" || lower == "starred" || lower == "favorite" || lower == "favorites" || lower == "★" {
                isStarredOnly = true
                continue
            }

            // 2. Built-In Category Aliases
            if categoryFilter == nil {
                if lower == "code" || lower == "codes" || lower == "programming" || lower == "<>" {
                    categoryFilter = .code
                    continue
                } else if lower == "prompt" || lower == "prompts" || lower == "instruction" || lower == "instructions" || lower == "✦" {
                    categoryFilter = .prompt
                    continue
                } else if lower == "url" || lower == "urls" || lower == "link" || lower == "links" || lower == "website" || lower == "websites" {
                    categoryFilter = .url
                    continue
                } else if lower == "emoji" || lower == "emojis" || lower == "smileys" || lower == "😊" {
                    categoryFilter = .emoji
                    continue
                } else if lower == "text" || lower == "texts" || lower == "plain" {
                    categoryFilter = .text
                    continue
                } else if lower == "image" || lower == "images" || lower == "photo" || lower == "photos" || lower == "pic" || lower == "picture" {
                    categoryFilter = .images
                    continue
                } else if lower == "collection" || lower == "collections" || lower == "folder" || lower == "folders" {
                    categoryFilter = .collections
                    continue
                }
            }

            // 3. Custom Category Name Check
            if customCategoryName == nil {
                if let matchedCustom = customCategoryNames.first(where: { $0.lowercased() == lower }) {
                    customCategoryName = matchedCustom
                    continue
                }
            }

            remainingTokens.append(token)
        }

        return ParsedSearchQuery(
            rawQuery: clean,
            categoryFilter: categoryFilter,
            isStarredOnly: isStarredOnly,
            customCategoryName: customCategoryName,
            textTerms: remainingTokens
        )
    }

    /// Filters and ranks a collection of clips given the active category tab and user query.
    public func filterAndRank(
        clips: [Clip],
        query: String,
        activeTabCategory: ClipCategory = .all,
        customCategories: [CustomCategoryItem] = []
    ) -> [Clip] {
        let customNames = customCategories.map { $0.title }
        let parsed = parse(query: query, customCategoryNames: customNames)

        // If no query and tab is .all, return in default recency order
        if parsed.isEmpty && activeTabCategory == .all {
            return clips
        }

        var scoredClips: [(clip: Clip, score: Double)] = []

        for clip in clips {
            // Check active category tab constraint
            if !activeTabCategory.matches(clip: clip) {
                continue
            }

            // Check parsed category filter constraint
            if let catFilter = parsed.categoryFilter, !catFilter.matches(clip: clip) {
                continue
            }

            // Check parsed star filter constraint
            if parsed.isStarredOnly && !clip.isStarred {
                continue
            }

            // Check custom category constraint
            if let customName = parsed.customCategoryName {
                if let item = customCategories.first(where: { $0.title.lowercased() == customName.lowercased() }) {
                    if let uuid = UUID(uuidString: item.id), !clip.collectionIds.contains(uuid) {
                        continue
                    }
                }
            }

            // If query is empty or filter-only, score is purely recency
            if parsed.textTerms.isEmpty {
                scoredClips.append((clip, clip.createdAt.timeIntervalSince1970))
                continue
            }

            // Calculate textual / metadata relevance score
            if let matchScore = calculateRelevanceScore(clip: clip, parsedQuery: parsed) {
                let finalScore = matchScore + (clip.createdAt.timeIntervalSince1970 / 100_000_000.0)
                scoredClips.append((clip, finalScore))
            }
        }

        // Sort descending by calculated score
        return scoredClips
            .sorted(by: { $0.score > $1.score })
            .map { $0.clip }
    }

    /// Computes deterministic relevance score for a clip against text terms and metadata.
    private func calculateRelevanceScore(clip: Clip, parsedQuery: ParsedSearchQuery) -> Double? {
        let terms = parsedQuery.textTerms.map { $0.lowercased() }
        let content = (clip.textContent ?? "").lowercased()
        let detectedLang = (clip.customMetadata["detectedLanguage"] ?? "").lowercased()
        let promptType = (clip.customMetadata["promptType"] ?? "").lowercased()
        let urlDomain = (clip.customMetadata["urlDomain"] ?? "").lowercased()
        let appName = (clip.sourceAppName ?? "").lowercased()

        var totalScore: Double = 0.0

        for term in terms {
            var termMatched = false

            // 1. Exact phrase match in content (+500)
            if content == term {
                totalScore += 500
                termMatched = true
            }
            // 2. Exact word / token match in content (+200)
            else if content.contains(" \(term) ") || content.hasPrefix("\(term) ") || content.hasSuffix(" \(term)") {
                totalScore += 200
                termMatched = true
            }
            // 3. Prefix match (+100)
            else if content.hasPrefix(term) {
                totalScore += 100
                termMatched = true
            }
            // 4. Substring content match (+50)
            else if content.contains(term) {
                totalScore += 50
                termMatched = true
            }

            // 5. Metadata match: Detected Language (+150)
            if !detectedLang.isEmpty && (detectedLang == term || detectedLang.contains(term)) {
                totalScore += 150
                termMatched = true
            }

            // 6. Metadata match: Prompt Type (+100)
            if !promptType.isEmpty && (promptType == term || promptType.contains(term)) {
                totalScore += 100
                termMatched = true
            }

            // 7. Metadata match: URL Domain (+150)
            if !urlDomain.isEmpty && (urlDomain == term || urlDomain.contains(term)) {
                totalScore += 150
                termMatched = true
            }

            // 8. Source App Name (+50)
            if !appName.isEmpty && (appName == term || appName.contains(term)) {
                totalScore += 50
                termMatched = true
            }

            // Every term in a multi-term query must match at least one signal
            if !termMatched {
                return nil
            }
        }

        return totalScore
    }
}

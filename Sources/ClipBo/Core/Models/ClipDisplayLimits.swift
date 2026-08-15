import Foundation

/// Centralized result display limits for UI presentation across Quick Overlay and Menu Bar Panel.
/// These are display/rendering limits only — they do NOT affect storage retention or delete clips from the database.
public struct ClipDisplayLimits: Sendable {
    /// Maximum visible clips displayed in the "All" category (30 clips).
    public static let all: Int = 30
    /// Maximum visible clips displayed in any individual category (Text, Code, Prompt, URL, Images, Emoji, Star, Collections, Custom) (20 clips).
    public static let perCategory: Int = 20

    /// Returns the appropriate display limit for a given category.
    public static func limit(for category: ClipCategory) -> Int {
        category == .all ? all : perCategory
    }
}

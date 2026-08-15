import Foundation
import SwiftUI

/// Categories for filtering clipboard history in Menu Bar Panel and Quick Overlay.
public enum ClipCategory: String, CaseIterable, Identifiable, Equatable, Hashable, Sendable {
    case all
    case text
    case star
    case code
    case prompt
    case url
    case images
    case emoji
    case collections

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .star: return "★ Star"
        case .code: return "<> Code"
        case .prompt: return "✦ Prompt"
        case .url: return "URL"
        case .images: return "Images"
        case .emoji: return "😊 Emoji"
        case .collections: return "Collections"
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .star: return "star.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .prompt: return "sparkles"
        case .url: return "link"
        case .images: return "photo"
        case .emoji: return "face.smiling"
        case .collections: return "folder"
        }
    }

    /// Evaluates if a given clip matches this category.
    public func matches(clip: Clip) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return clip.type == .text
        case .star:
            return clip.isStarred
        case .code:
            return clip.type == .code
        case .prompt:
            return clip.type == .prompt
        case .url:
            return clip.type == .url
        case .images:
            return clip.type == .image
        case .emoji:
            if clip.customMetadata["isEmoji"] == "true" {
                return true
            }
            if let text = clip.textContent, !text.isEmpty {
                return DefaultContentClassifier.evaluateEmojiContent(text).isEmoji
            }
            return false
        case .collections:
            return !clip.collectionIds.isEmpty
        }
    }

    /// Returns next category in horizontal sequence given available categories.
    public func next(in available: [ClipCategory] = ClipCategory.allCases) -> ClipCategory {
        guard let index = available.firstIndex(of: self) else { return available.first ?? .all }
        let nextIndex = (index + 1) % available.count
        return available[nextIndex]
    }

    /// Returns previous category in horizontal sequence given available categories.
    public func previous(in available: [ClipCategory] = ClipCategory.allCases) -> ClipCategory {
        guard let index = available.firstIndex(of: self) else { return available.first ?? .all }
        let prevIndex = (index - 1 + available.count) % available.count
        return available[prevIndex]
    }
}

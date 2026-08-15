import Foundation

/// Represents the high-level category of content captured by ClipBo.
public enum ClipType: String, Codable, Sendable, CaseIterable {
    case text
    case image
    case url
    case code
    case prompt
}

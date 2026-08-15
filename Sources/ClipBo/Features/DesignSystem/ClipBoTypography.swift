import SwiftUI
import AppKit

/// Centralized native macOS typography system for ClipBo following Apple's SF Pro / system font hierarchy.
public enum ClipBoTypography {
    /// Base system font scaled dynamically by `scale`.
    public static func system(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, scale: Double = 1.0) -> Font {
        Font.system(size: max(6, size * CGFloat(scale)), weight: weight, design: design)
    }

    /// Monospaced system font scaled dynamically by `scale`.
    public static func mono(size: CGFloat, weight: Font.Weight = .regular, scale: Double = 1.0) -> Font {
        Font.system(size: max(6, size * CGFloat(scale)), weight: weight, design: .monospaced)
    }

    // Dynamic Scaled Styles
    public static func appTitle(scale: Double = 1.0) -> Font { system(size: 13, weight: .semibold, scale: scale) }
    public static func title(scale: Double = 1.0) -> Font { system(size: 14, weight: .bold, scale: scale) }
    public static func sectionTitle(scale: Double = 1.0) -> Font { system(size: 12, weight: .semibold, scale: scale) }
    public static func body(scale: Double = 1.0) -> Font { system(size: 12, weight: .regular, scale: scale) }
    public static func bodyMedium(scale: Double = 1.0) -> Font { system(size: 12, weight: .medium, scale: scale) }
    public static func secondary(scale: Double = 1.0) -> Font { system(size: 11, weight: .regular, scale: scale) }
    public static func caption(scale: Double = 1.0) -> Font { system(size: 10, weight: .regular, scale: scale) }
    public static func code(scale: Double = 1.0) -> Font { mono(size: 11, weight: .regular, scale: scale) }
    public static func menuLabel(scale: Double = 1.0) -> Font { system(size: 11, weight: .medium, scale: scale) }
    public static func badge(scale: Double = 1.0) -> Font { mono(size: 9, weight: .semibold, scale: scale) }

    /// Primary clip content text — slightly larger and bolder than bodyMedium for excellent native readability.
    public static func clipContent(scale: Double = 1.0) -> Font { system(size: 13, weight: .medium, scale: scale) }

    /// Monospaced code content — slightly larger than code() for better readability of code clips.
    public static func codeContent(scale: Double = 1.0) -> Font { mono(size: 12, weight: .regular, scale: scale) }

    // Static standard styles (scale = 1.0)
    public static let appTitle = appTitle()
    public static let title = title()
    public static let sectionTitle = sectionTitle()
    public static let body = body()
    public static let bodyMedium = bodyMedium()
    public static let secondary = secondary()
    public static let caption = caption()
    public static let code = code()
    public static let clipContent = clipContent()
    public static let codeContent = codeContent()
    public static let menuLabel = menuLabel()
    public static let badge = badge()
}

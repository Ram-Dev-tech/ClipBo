import SwiftUI
import AppKit

/// Shared design system tokens for ClipBo macOS interfaces.
public enum DesignTokens {
    // MARK: - Geometry & Dimensions
    public enum Dimensions {
        public static let menuBarWidth: CGFloat = 420
        public static let menuBarHeight: CGFloat = 480
        
        public static let quickOverlayWidth: CGFloat = 560
        public static let quickOverlayMaxHeight: CGFloat = 440
        
        public static let panelCornerRadius: CGFloat = 12
        public static let itemCornerRadius: CGFloat = 8
        public static let categoryPillCornerRadius: CGFloat = 6
        public static let searchFieldCornerRadius: CGFloat = 8
        
        public static let searchFieldHeight: CGFloat = 32
        public static let categoryRowHeight: CGFloat = 28
        public static let clipRowMinHeight: CGFloat = 46
        public static let imageThumbnailSize: CGFloat = 90
    }

    // MARK: - Spacing
    public enum Spacing {
        public static let standard: CGFloat = 12
        public static let compact: CGFloat = 8
        public static let tight: CGFloat = 4
        public static let relaxed: CGFloat = 16
    }

    // MARK: - Colors & Surfaces
    public enum Colors {
        public static let panelBorder = Color.primary.opacity(0.09)
        public static let searchBackground = Color.primary.opacity(0.05)
        public static let hoverBackground = Color.primary.opacity(0.06)
        public static let selectedBackground = Color.accentColor.opacity(0.18)
        public static let activePillBackground = Color.primary.opacity(0.12)
        public static let secondaryText = Color.secondary
        public static let tertiaryText = Color.secondary.opacity(0.7)
        public static let starGold = Color.orange
    }

    // MARK: - Animations
    public enum Animations {
        public static let fast = Animation.easeOut(duration: 0.12)
        public static let standard = Animation.easeInOut(duration: 0.18)
        public static let pillSpring = Animation.spring(response: 0.26, dampingFraction: 0.78)
        public static let overlayTransition = Animation.spring(response: 0.22, dampingFraction: 0.85)
    }
}

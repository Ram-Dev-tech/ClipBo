import SwiftUI

/// Compact Spotlight-style circular category row appearing alongside the search field in Quick Overlay.
/// Always visible in the header regardless of navigation state.
public struct QuickOverlayCategoryRow: View {
    @Binding public var selectedCategory: ClipCategory
    public var categories: [CustomCategoryItem]
    public var fontScale: Double
    /// When true, uses smaller circles and tighter spacing to fit narrow windows.
    public var isCompact: Bool
    /// When true, indicates keyboard focus is actively navigating categories.
    public var isCategoryFocused: Bool
    public var onCategorySelected: ((ClipCategory) -> Void)?

    public init(
        selectedCategory: Binding<ClipCategory>,
        categories: [CustomCategoryItem] = CustomCategoryItem.defaultBuiltInCategories,
        fontScale: Double = 1.0,
        isCompact: Bool = false,
        isCategoryFocused: Bool = false,
        onCategorySelected: ((ClipCategory) -> Void)? = nil
    ) {
        self._selectedCategory = selectedCategory
        self.categories = categories
        self.fontScale = fontScale
        self.isCompact = isCompact
        self.isCategoryFocused = isCategoryFocused
        self.onCategorySelected = onCategorySelected
    }

    private var circleSize: CGFloat { isCompact ? 22 : 26 }
    private var iconSize: CGFloat { isCompact ? 9.5 : 11 }
    private var spacing: CGFloat { isCompact ? 3 : 5 }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(categories) { catItem in
                let clipCat = ClipCategory(rawValue: catItem.id) ?? .all
                let isSelected = selectedCategory == clipCat

                CircularCategoryButton(
                    item: catItem,
                    clipCategory: clipCat,
                    isSelected: isSelected,
                    isCategoryFocused: isCategoryFocused,
                    fontScale: fontScale,
                    circleSize: circleSize,
                    iconSize: iconSize
                ) {
                    withAnimation(DesignTokens.Animations.pillSpring) {
                        selectedCategory = clipCat
                        onCategorySelected?(clipCat)
                    }
                }
            }
        }
    }
}

/// Individual circular category icon button with Spotlight active glow and native material.
private struct CircularCategoryButton: View {
    let item: CustomCategoryItem
    let clipCategory: ClipCategory
    let isSelected: Bool
    let isCategoryFocused: Bool
    let fontScale: Double
    let circleSize: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.40), radius: isCategoryFocused ? 7 : 5, x: 0, y: 1)
                        .overlay {
                            if isCategoryFocused {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.80), lineWidth: 1.5)
                            }
                        }
                } else {
                    Circle()
                        .fill(Color.primary.opacity(isHovered ? 0.14 : 0.08))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(isHovered ? 0.22 : 0.12), lineWidth: 0.8)
                        )
                }

                Image(systemName: iconName)
                    .font(.system(size: iconSize * CGFloat(fontScale), weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : (isHovered ? Color.primary : Color.secondary))
            }
            .frame(width: circleSize, height: circleSize)
            .scaleEffect(isHovered && !isSelected ? 1.08 : (isCategoryFocused && isSelected ? 1.05 : 1.0))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animations.fast) {
                isHovered = hovering
            }
        }
        .help(item.title)
    }

    private var iconName: String {
        if !item.iconName.isEmpty {
            return item.iconName
        }
        return clipCategory.iconName
    }
}

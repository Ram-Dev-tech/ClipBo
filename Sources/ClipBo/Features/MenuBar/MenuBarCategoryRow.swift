import SwiftUI

/// Single horizontal category navigation bar for the Menu Bar Panel with dynamic category order, animated pill, and expanded hit areas.
public struct MenuBarCategoryRow: View {
    @Binding public var selectedCategory: ClipCategory
    public var categories: [CustomCategoryItem]
    public var isCategoryFocused: Bool
    public var fontScale: Double
    @Namespace private var categoryNamespace

    public init(
        selectedCategory: Binding<ClipCategory>,
        categories: [CustomCategoryItem] = CustomCategoryItem.defaultBuiltInCategories,
        isCategoryFocused: Bool = false,
        fontScale: Double = 1.0
    ) {
        self._selectedCategory = selectedCategory
        self.categories = categories
        self.isCategoryFocused = isCategoryFocused
        self.fontScale = fontScale
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(categories) { catItem in
                    let clipCat = ClipCategory(rawValue: catItem.id) ?? .all
                    let isSelected = selectedCategory == clipCat

                    Button {
                        withAnimation(DesignTokens.Animations.pillSpring) {
                            selectedCategory = clipCat
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if catItem.id == "star" {
                                Image(systemName: "star.fill")
                                    .font(ClipBoTypography.badge(scale: fontScale))
                                    .foregroundStyle(isSelected ? DesignTokens.Colors.starGold : Color.secondary)
                            }
                            Text(catItem.title.replacingOccurrences(of: "★ ", with: ""))
                                .font(ClipBoTypography.caption(scale: fontScale))
                                .fontWeight(isSelected ? .semibold : .medium)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.primary.opacity(0.12))
                                    .matchedGeometryEffect(id: "MenuBarCategoryActivePill", in: categoryNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

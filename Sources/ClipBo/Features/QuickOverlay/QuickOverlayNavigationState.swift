import Foundation

/// Navigation state for the Spotlight-style Quick Overlay.
public enum QuickOverlayNavigationState: Equatable, Sendable {
    /// Text search input and results list navigation.
    case search
    /// Circular category navigation alongside search field.
    case categories
}

/// Controller managing keyboard and state transitions for the Spotlight-style Quick Overlay.
public final class QuickOverlayNavigationController: ObservableObject, @unchecked Sendable {
    @Published public var state: QuickOverlayNavigationState = .search
    @Published public var selectedCategoryId: String = "all" {
        didSet {
            selectedCategory = ClipCategory(rawValue: selectedCategoryId) ?? .all
        }
    }
    @Published public var selectedCategory: ClipCategory = .all
    @Published public var selectedResultIndex: Int = 0

    public init() {
        self.state = .search
        self.selectedCategory = .all
        self.selectedCategoryId = "all"
    }

    public init(initialState: QuickOverlayNavigationState, initialCategory: ClipCategory) {
        self.state = initialState
        self.selectedCategory = initialCategory
        self.selectedCategoryId = initialCategory.rawValue
    }

    public init(initialState: QuickOverlayNavigationState, initialCategoryId: String) {
        self.state = initialState
        self.selectedCategoryId = initialCategoryId
        self.selectedCategory = ClipCategory(rawValue: initialCategoryId) ?? .all
    }

    // MARK: - Category Arrow Navigation (CustomCategoryItem)

    /// Handles right arrow navigation using active CustomCategoryItems from SettingsService.
    /// In search state: transitions into categories mode and focuses active category.
    /// In categories state: advances to the next category with circular wrap-around (last -> first).
    public func handleRightArrow(activeCategories: [CustomCategoryItem]) {
        guard !activeCategories.isEmpty else { return }
        switch state {
        case .search:
            state = .categories
            if !activeCategories.contains(where: { $0.id == selectedCategoryId }), let first = activeCategories.first {
                selectedCategoryId = first.id
            }
        case .categories:
            if let currentIndex = activeCategories.firstIndex(where: { $0.id == selectedCategoryId }) {
                let nextIndex = (currentIndex + 1) % activeCategories.count
                selectedCategoryId = activeCategories[nextIndex].id
            } else if let first = activeCategories.first {
                selectedCategoryId = first.id
            }
        }
        selectedResultIndex = 0
    }

    /// Handles left arrow navigation using active CustomCategoryItems from SettingsService.
    /// In search state: no-op (leaves cursor movement to search text field).
    /// In categories state: moves to previous category, or returns to search state if already at the first category.
    public func handleLeftArrow(activeCategories: [CustomCategoryItem]) {
        guard !activeCategories.isEmpty else { return }
        switch state {
        case .search:
            break
        case .categories:
            if let currentIndex = activeCategories.firstIndex(where: { $0.id == selectedCategoryId }) {
                if currentIndex == 0 {
                    // At first category, left arrow returns back to search state
                    state = .search
                } else {
                    let prevIndex = currentIndex - 1
                    selectedCategoryId = activeCategories[prevIndex].id
                }
            } else {
                state = .search
            }
        }
        selectedResultIndex = 0
    }

    // MARK: - Backwards Compatibility with [ClipCategory]

    public func handleRightArrow(availableCategories: [ClipCategory]) {
        let customItems = availableCategories.map { CustomCategoryItem(id: $0.rawValue, title: $0.title, iconName: $0.iconName) }
        handleRightArrow(activeCategories: customItems)
    }

    public func handleLeftArrow(availableCategories: [ClipCategory]) {
        let customItems = availableCategories.map { CustomCategoryItem(id: $0.rawValue, title: $0.title, iconName: $0.iconName) }
        handleLeftArrow(activeCategories: customItems)
    }

    // MARK: - Enter Key Handling

    /// Handles Enter key activation.
    /// In categories state: confirms category filter and returns to search/results view without copying.
    /// In search state: returns true to trigger copy/restore on the selected clip.
    public func handleEnter() -> Bool {
        switch state {
        case .categories:
            // Apply category and return to search view with filter active
            state = .search
            selectedResultIndex = 0
            return false // Did not copy clip, applied category filter
        case .search:
            return true // Trigger copy/restore on selected clip
        }
    }

    // MARK: - Up / Down Result Navigation

    /// Handles down arrow navigation with circular wrap-around (last + ↓ → first).
    public func handleDownArrow(totalResults: Int) {
        guard totalResults > 0 else { return }
        if selectedResultIndex >= totalResults - 1 {
            selectedResultIndex = 0
        } else {
            selectedResultIndex += 1
        }
    }

    /// Handles up arrow navigation with circular wrap-around (first + ↑ → last).
    public func handleUpArrow(totalResults: Int) {
        guard totalResults > 0 else { return }
        if selectedResultIndex <= 0 {
            selectedResultIndex = totalResults - 1
        } else {
            selectedResultIndex -= 1
        }
    }

    /// Selects a category directly and resets result index.
    public func selectCategory(_ category: ClipCategory) {
        selectedCategoryId = category.rawValue
        selectedCategory = category
        selectedResultIndex = 0
    }

    /// Selects a custom category item directly and resets result index.
    public func selectCategoryItem(_ item: CustomCategoryItem) {
        selectedCategoryId = item.id
        selectedResultIndex = 0
    }

    /// Validates and clamps selectedResultIndex to safe bounds given total results.
    public func clampSelection(totalResults: Int) {
        if totalResults <= 0 {
            selectedResultIndex = 0
        } else if selectedResultIndex >= totalResults {
            selectedResultIndex = max(0, totalResults - 1)
        } else if selectedResultIndex < 0 {
            selectedResultIndex = 0
        }
    }
}

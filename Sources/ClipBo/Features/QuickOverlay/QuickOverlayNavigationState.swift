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
    @Published public var selectedCategory: ClipCategory = .all
    @Published public var selectedResultIndex: Int = 0

    public init(initialState: QuickOverlayNavigationState = .search, initialCategory: ClipCategory = .all) {
        self.state = initialState
        self.selectedCategory = initialCategory
    }

    /// Handles right arrow navigation.
    /// In search state: transitions into categories mode.
    /// In categories state: advances to the next active category with wrap-around (last -> first).
    public func handleRightArrow(availableCategories: [ClipCategory]) {
        guard !availableCategories.isEmpty else { return }
        switch state {
        case .search:
            state = .categories
            if !availableCategories.contains(selectedCategory), let first = availableCategories.first {
                selectedCategory = first
            }
        case .categories:
            selectedCategory = selectedCategory.next(in: availableCategories)
        }
        selectedResultIndex = 0
    }

    /// Handles left arrow navigation.
    /// In search state: no-op (leaves cursor movement to search text field).
    /// In categories state: moves to previous category, or returns to search state if already at the first category.
    public func handleLeftArrow(availableCategories: [ClipCategory]) {
        guard !availableCategories.isEmpty else { return }
        switch state {
        case .search:
            // Remain in search for cursor navigation
            break
        case .categories:
            if let first = availableCategories.first, selectedCategory == first {
                // If on the first category, return back to normal search state
                state = .search
            } else {
                selectedCategory = selectedCategory.previous(in: availableCategories)
            }
        }
        selectedResultIndex = 0
    }

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
        selectedCategory = category
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

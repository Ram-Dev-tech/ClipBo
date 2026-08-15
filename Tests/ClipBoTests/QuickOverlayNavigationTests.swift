import Foundation
import ClipBo

public struct QuickOverlayNavigationTests {
    public static func runAll() {
        print("  ▶ Running QuickOverlayNavigationTests...")

        let available: [ClipCategory] = [.all, .text, .star, .code, .prompt, .url, .images, .emoji, .collections]

        // 1. Initial State
        let controller = QuickOverlayNavigationController(initialState: .search, initialCategory: .all)
        assert(controller.state == .search, "Initial state should be .search")
        assert(controller.selectedCategory == .all, "Initial category should be .all")
        assert(controller.selectedResultIndex == 0, "Initial result index should be 0")

        // 2. Right arrow from search -> categories
        print("    ▶ Testing Right arrow transition into categories...")
        controller.handleRightArrow(availableCategories: available)
        assert(controller.state == .categories, "Expected state .categories after right arrow")
        assert(controller.selectedCategory == .all, "Expected selected category .all")

        // 3. Category cycling via Right arrow
        print("    ▶ Testing Category cycling via Right arrow...")
        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .text, "Expected .text after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .star, "Expected .star after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .code, "Expected .code after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .prompt, "Expected .prompt after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .url, "Expected .url after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .images, "Expected .images after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .emoji, "Expected .emoji after right arrow")

        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .collections, "Expected .collections after right arrow")

        // Circular wrap back to first category (.all)
        controller.handleRightArrow(availableCategories: available)
        assert(controller.selectedCategory == .all, "Expected wrap back to .all")
        print("      ✔ Category cycling via Right arrow with circular wrap-around verified")

        // 4. Category cycling via Left arrow
        print("    ▶ Testing Category cycling via Left arrow...")
        controller.selectedCategory = .code
        controller.selectedCategoryId = "code"
        controller.handleLeftArrow(availableCategories: available)
        assert(controller.selectedCategory == .star, "Expected .star after left arrow from .code")

        controller.handleLeftArrow(availableCategories: available)
        assert(controller.selectedCategory == .text, "Expected .text after left arrow from .star")

        controller.handleLeftArrow(availableCategories: available)
        assert(controller.selectedCategory == .all, "Expected .all after left arrow from .text")

        // 5. First category + Left arrow returns to .search
        print("    ▶ Testing First category + Left arrow returns to search...")
        controller.handleLeftArrow(availableCategories: available)
        assert(controller.state == .search, "Expected transition back to .search when pressing left arrow on first category")
        print("      ✔ First category + Left arrow safely transitions back to search without closing")

        // 6. Testing CustomCategoryItem list navigation (dynamic order + custom categories)
        print("    ▶ Testing CustomCategoryItem list navigation with custom category...")
        let customCat = CustomCategoryItem(id: "custom_notes", title: "My Notes", iconName: "note.text")
        let dynamicCategories: [CustomCategoryItem] = [
            CustomCategoryItem(id: "all", title: "All", iconName: "square.grid.2x2"),
            CustomCategoryItem(id: "code", title: "<> Code", iconName: "chevron.left.forwardslash.chevron.right"),
            customCat,
            CustomCategoryItem(id: "url", title: "URL", iconName: "link")
        ]

        let dynamicController = QuickOverlayNavigationController(initialState: .search, initialCategoryId: "all")
        dynamicController.handleRightArrow(activeCategories: dynamicCategories)
        assert(dynamicController.state == .categories, "Expected transition to categories")
        assert(dynamicController.selectedCategoryId == "all", "Expected 'all' selected")

        dynamicController.handleRightArrow(activeCategories: dynamicCategories)
        assert(dynamicController.selectedCategoryId == "code", "Expected 'code' selected next")

        dynamicController.handleRightArrow(activeCategories: dynamicCategories)
        assert(dynamicController.selectedCategoryId == "custom_notes", "Expected custom category 'custom_notes' selected")

        dynamicController.handleRightArrow(activeCategories: dynamicCategories)
        assert(dynamicController.selectedCategoryId == "url", "Expected 'url' selected")

        // Wrap around to 'all'
        dynamicController.handleRightArrow(activeCategories: dynamicCategories)
        assert(dynamicController.selectedCategoryId == "all", "Expected wrap around to 'all'")

        // Left arrow from 'all' returns to search
        dynamicController.handleLeftArrow(activeCategories: dynamicCategories)
        assert(dynamicController.state == .search, "Expected state .search after left from first item")
        print("      ✔ CustomCategoryItem dynamic navigation and custom category inclusion verified")

        // 7. Enter key behavior
        print("    ▶ Testing Enter key behavior in categories vs search...")
        controller.state = .categories
        controller.selectedCategory = .prompt
        let shouldCopyFromCategories = controller.handleEnter()
        assert(!shouldCopyFromCategories, "Enter in .categories should apply filter and return false for copy")
        assert(controller.state == .search, "Enter in .categories should transition state back to .search")
        assert(controller.selectedCategory == .prompt, "Category .prompt should remain active filter")

        let shouldCopyFromSearch = controller.handleEnter()
        assert(shouldCopyFromSearch, "Enter in .search should return true to trigger clip copy/restore")
        print("      ✔ Enter key differentiation between category selection and clip copy verified")

        // 8. Up / Down arrow result navigation with circular wrap-around
        print("    ▶ Testing Up / Down arrow result navigation with wrap-around...")
        controller.selectedResultIndex = 0
        controller.handleDownArrow(totalResults: 3)
        assert(controller.selectedResultIndex == 1, "Down arrow should increment index to 1")

        controller.handleDownArrow(totalResults: 3)
        assert(controller.selectedResultIndex == 2, "Down arrow should increment index to 2 (last)")

        // Wrap around: last + ↓ -> first (0)
        controller.handleDownArrow(totalResults: 3)
        assert(controller.selectedResultIndex == 0, "Down arrow at last item should wrap around to index 0")

        // Wrap around: first + ↑ -> last (2)
        controller.handleUpArrow(totalResults: 3)
        assert(controller.selectedResultIndex == 2, "Up arrow at index 0 should wrap around to index 2 (last)")

        controller.handleUpArrow(totalResults: 3)
        assert(controller.selectedResultIndex == 1, "Up arrow should decrement index to 1")

        controller.handleUpArrow(totalResults: 3)
        assert(controller.selectedResultIndex == 0, "Up arrow should decrement index to 0")

        // Zero results safety
        controller.handleUpArrow(totalResults: 0)
        assert(controller.selectedResultIndex == 0, "Up arrow with 0 results should do nothing")
        controller.handleDownArrow(totalResults: 0)
        assert(controller.selectedResultIndex == 0, "Down arrow with 0 results should do nothing")
        print("      ✔ Up/Down arrow result navigation with wrap-around (first + ↑ -> last, last + ↓ -> first) verified")

        // 9. Direct selection and index safety
        print("    ▶ Testing direct category selection & clampSelection...")
        controller.selectCategory(.images)
        assert(controller.selectedCategory == .images, "Selected category should be .images")
        assert(controller.selectedResultIndex == 0, "Result index should reset to 0 on category change")

        controller.selectedResultIndex = 15
        controller.clampSelection(totalResults: 5)
        assert(controller.selectedResultIndex == 4, "clampSelection should clamp index to totalResults - 1")

        controller.clampSelection(totalResults: 0)
        assert(controller.selectedResultIndex == 0, "clampSelection with 0 results should reset index to 0")
        print("      ✔ Direct category selection & clampSelection safety verified")

        // 10. Overlay Geometry Constraints (520x300 min, 600x380 default, 1000x700 max)
        print("    ▶ Testing OverlayGeometry constraints...")
        assert(OverlayGeometry.minWidth == 520, "minWidth must be 520")
        assert(OverlayGeometry.minHeight == 300, "minHeight must be 300")
        assert(OverlayGeometry.defaultGeometry.width == 600, "default width must be 600")
        assert(OverlayGeometry.defaultGeometry.height == 380, "default height must be 380")
        assert(OverlayGeometry.maxWidth == 1000, "maxWidth must be 1000")
        assert(OverlayGeometry.maxHeight == 700, "maxHeight must be 700")

        let clampedBelowMin = OverlayGeometry(width: 400, height: 200)
        assert(clampedBelowMin.width == 520, "Should clamp width up to 520")
        assert(clampedBelowMin.height == 300, "Should clamp height up to 300")

        let clampedAboveMax = OverlayGeometry(width: 1500, height: 900)
        assert(clampedAboveMax.width == 1000, "Should clamp width down to 1000")
        assert(clampedAboveMax.height == 700, "Should clamp height down to 700")
        print("      ✔ OverlayGeometry hard bounds (520x300, 600x380, 1000x700) verified")

        print("  ✔ QuickOverlayNavigationTests passed")
    }
}

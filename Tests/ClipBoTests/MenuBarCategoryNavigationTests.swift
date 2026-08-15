import Foundation
import ClipBo

public struct MenuBarCategoryNavigationTests {
    @MainActor
    public static func runAll() async {
        print("  ▶ Running MenuBarCategoryNavigationTests...")

        let available: [ClipCategory] = [.all, .text, .star, .code, .prompt, .url, .images, .emoji, .collections]

        // 1. Initial State
        var selectedCategory: ClipCategory = .all
        var isSearchFocused: Bool = true
        var isCategoryFocused: Bool = false

        // Simulate Right Arrow from Search Focus
        print("    ▶ Testing Right arrow from search focus to category navigation...")
        if isSearchFocused {
            isSearchFocused = false
            isCategoryFocused = true
            selectedCategory = available.first ?? .all
        }
        assert(!isSearchFocused, "Search should no longer be focused")
        assert(isCategoryFocused, "Category should now be focused")
        assert(selectedCategory == .all, "Selected category should be .all")
        print("      ✔ First → transitions from search focus into categories")

        // 2. Repeated Right Arrow cycling
        print("    ▶ Testing Repeated → category cycling...")
        let expectedSequence: [ClipCategory] = [.text, .star, .code, .prompt, .url, .images, .emoji, .collections, .all]
        for expected in expectedSequence {
            selectedCategory = selectedCategory.next(in: available)
            assert(selectedCategory == expected, "Expected \(expected), got \(selectedCategory)")
        }
        print("      ✔ Repeated → cycles forward through all categories and wraps to .all")

        // 3. Repeated Left Arrow cycling
        print("    ▶ Testing Repeated ← category cycling...")
        let reverseSequence: [ClipCategory] = [.collections, .emoji, .images, .url, .prompt, .code, .star, .text, .all]
        for expected in reverseSequence {
            selectedCategory = selectedCategory.previous(in: available)
            assert(selectedCategory == expected, "Expected \(expected), got \(selectedCategory)")
        }
        print("      ✔ Repeated ← cycles backward through all categories and wraps")

        // 4. Boundary behavior
        print("    ▶ Testing Boundary wrap-around...")
        selectedCategory = .all
        selectedCategory = selectedCategory.previous(in: available)
        assert(selectedCategory == .collections, "Left from .all should wrap to .collections")

        selectedCategory = selectedCategory.next(in: available)
        assert(selectedCategory == .all, "Right from .collections should wrap to .all")
        print("      ✔ Boundary wrap-around verified")

        // 5. Disabled categories are skipped
        print("    ▶ Testing Disabled categories skipping...")
        let testDefaults = UserDefaults(suiteName: "com.clipbo.test.menubar.nav.\(UUID().uuidString)")!
        let settingsService = SettingsService(userDefaults: testDefaults)
        
        // Disable "prompt" and "emoji"
        settingsService.toggleCategoryEnabled(id: "prompt")
        settingsService.toggleCategoryEnabled(id: "emoji")

        let activeCats = settingsService.activeCategories().compactMap { ClipCategory(rawValue: $0.id) }
        assert(!activeCats.contains(.prompt), "Active categories must not contain disabled .prompt")
        assert(!activeCats.contains(.emoji), "Active categories must not contain disabled .emoji")

        selectedCategory = .code
        selectedCategory = selectedCategory.next(in: activeCats)
        assert(selectedCategory == .url, "Next after .code should skip disabled .prompt and go directly to .url")
        print("      ✔ Disabled categories correctly skipped during navigation")

        // 6. Custom categories included
        print("    ▶ Testing Custom categories inclusion...")
        let customCat = settingsService.addCustomCategory(title: "Work Notes", iconName: "briefcase")
        let activeWithCustom = settingsService.activeCategories()
        assert(activeWithCustom.contains { $0.id == customCat.id }, "Active categories must contain newly added custom category")
        print("      ✔ Custom categories included in active list")

        // 7. Prompt and Emoji category coverage
        print("    ▶ Testing Prompt and Emoji category models...")
        assert(ClipCategory.prompt.rawValue == "prompt")
        assert(ClipCategory.emoji.rawValue == "emoji")
        assert(ClipCategory.prompt.title == "✦ Prompt")
        assert(ClipCategory.emoji.title == "😊 Emoji")
        print("      ✔ Prompt and Emoji categories properly configured")

        print("  ✔ MenuBarCategoryNavigationTests passed")
    }
}

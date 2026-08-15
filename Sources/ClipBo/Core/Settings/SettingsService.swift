import Foundation
import Combine
import OSLog

public enum ShortcutValidationError: LocalizedError, Sendable {
    case missingModifier
    case conflict(String)
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .missingModifier:
            return "Shortcut must contain at least one modifier key (⌘, ⌥, ⌃, or ⇧)."
        case .conflict(let name):
            return "This shortcut is already assigned to \(name)."
        case .registrationFailed(let status):
            return "System could not register shortcut (OSStatus: \(status))."
        }
    }
}

/// Central observable service managing application preferences and coordinating live updates.
@MainActor
public final class SettingsService: ObservableObject {
    private let logger = Logger(subsystem: "com.clipbo.app", category: "SettingsService")
    private let userDefaults: UserDefaults
    private let storageKey = "com.clipbo.app.settings"

    @Published public var settings: AppSettings {
        didSet {
            save()
        }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
            logger.info("Loaded persisted AppSettings from UserDefaults")
        } else {
            self.settings = AppSettings.default
            logger.info("Initialized default AppSettings")
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: storageKey)
            logger.debug("Saved AppSettings to UserDefaults")
        }
    }

    // MARK: - Overlay Geometry & Position Management

    public func updateOverlayGeometry(width: Double, height: Double, originX: Double?, originY: Double?) {
        let updated = OverlayGeometry(
            width: width,
            height: height,
            originX: originX,
            originY: originY
        )
        if settings.overlayGeometry != updated {
            settings.overlayGeometry = updated
            logger.debug("Updated overlay geometry: \(width)x\(height) at (\(originX ?? 0), \(originY ?? 0))")
        }
    }

    public func resetOverlayGeometry() {
        settings.overlayGeometry = .defaultGeometry
        logger.info("Reset overlay geometry to default.")
    }

    // MARK: - Category Management

    public func allCategories() -> [CustomCategoryItem] {
        var builtInMap: [String: CustomCategoryItem] = [:]
        for cat in CustomCategoryItem.defaultBuiltInCategories {
            builtInMap[cat.id] = cat
        }
        var customMap: [String: CustomCategoryItem] = [:]
        for cat in settings.customCategories {
            customMap[cat.id] = cat
        }

        var ordered: [CustomCategoryItem] = []
        var seen = Set<String>()

        for id in settings.categoryOrder {
            if let item = builtInMap[id] {
                var finalItem = item
                finalItem.isEnabled = !settings.disabledCategoryIds.contains(id)
                ordered.append(finalItem)
                seen.insert(id)
            } else if let item = customMap[id] {
                var finalItem = item
                finalItem.isEnabled = !settings.disabledCategoryIds.contains(id)
                ordered.append(finalItem)
                seen.insert(id)
            }
        }

        // Append any unreferenced built-in categories
        for cat in CustomCategoryItem.defaultBuiltInCategories {
            if !seen.contains(cat.id) {
                var item = cat
                item.isEnabled = !settings.disabledCategoryIds.contains(cat.id)
                ordered.append(item)
                seen.insert(cat.id)
            }
        }

        // Append any unreferenced custom categories
        for cat in settings.customCategories {
            if !seen.contains(cat.id) {
                var item = cat
                item.isEnabled = !settings.disabledCategoryIds.contains(cat.id)
                ordered.append(item)
                seen.insert(cat.id)
            }
        }

        return ordered
    }

    public func activeCategories() -> [CustomCategoryItem] {
        allCategories().filter { $0.isEnabled }
    }

    @discardableResult
    public func addCustomCategory(title: String, iconName: String) -> CustomCategoryItem {
        let newCat = CustomCategoryItem(id: UUID().uuidString, title: title, iconName: iconName, isEnabled: true, isBuiltIn: false)
        settings.customCategories.append(newCat)
        settings.categoryOrder.append(newCat.id)
        logger.info("Added custom category: \(title) (\(newCat.id))")
        return newCat
    }

    public func renameCategory(id: String, newTitle: String) {
        if let idx = settings.customCategories.firstIndex(where: { $0.id == id }) {
            settings.customCategories[idx].title = newTitle
            logger.info("Renamed category \(id) to '\(newTitle)'")
        }
    }

    public func updateCategoryIcon(id: String, newIconName: String) {
        if let idx = settings.customCategories.firstIndex(where: { $0.id == id }) {
            settings.customCategories[idx].iconName = newIconName
            logger.info("Updated icon for category \(id) to '\(newIconName)'")
        }
    }

    public func toggleCategoryEnabled(id: String) {
        if id == "all" { return } // "all" cannot be disabled

        if settings.disabledCategoryIds.contains(id) {
            settings.disabledCategoryIds.removeAll { $0 == id }
        } else {
            settings.disabledCategoryIds.append(id)
        }
        if let idx = settings.customCategories.firstIndex(where: { $0.id == id }) {
            settings.customCategories[idx].isEnabled.toggle()
        }
        logger.info("Toggled category \(id) visibility")
    }

    @discardableResult
    public func deleteCustomCategory(id: String) -> Bool {
        // Built-in categories cannot be deleted
        if CustomCategoryItem.defaultBuiltInCategories.contains(where: { $0.id == id }) {
            return false
        }
        settings.customCategories.removeAll { $0.id == id }
        settings.categoryOrder.removeAll { $0 == id }
        settings.disabledCategoryIds.removeAll { $0 == id }
        logger.info("Deleted custom category: \(id)")
        return true
    }

    public func moveCategory(id: String, direction: Int) {
        var current = allCategories().map { $0.id }
        guard let idx = current.firstIndex(of: id) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0 && newIdx < current.count else { return }
        current.swapAt(idx, newIdx)
        settings.categoryOrder = current
        logger.info("Moved category \(id) to index \(newIdx)")
    }

    public func reorderCategories(newOrder: [String]) {
        settings.categoryOrder = newOrder
        logger.info("Updated category order")
    }

    // MARK: - Global Shortcuts

    /// Validates and updates the Quick Overlay shortcut, immediately applying it to GlobalShortcutManager.
    public func updateQuickOverlayShortcut(_ newShortcut: KeyCombination) -> Result<Void, ShortcutValidationError> {
        guard newShortcut.modifiers != 0 else {
            return .failure(.missingModifier)
        }

        if newShortcut == settings.quickCaptureShortcut {
            return .failure(.conflict("Quick Selection Capture"))
        }
        if newShortcut == settings.menuBarPanelShortcut {
            return .failure(.conflict("Menu Bar Panel"))
        }

        let previous = settings.quickOverlayShortcut
        let status = GlobalShortcutManager.shared.registerQuickOverlayShortcut(
            keyCode: newShortcut.keyCode,
            modifiers: newShortcut.modifiers
        )

        if status == 0 { // noErr
            settings.quickOverlayShortcut = newShortcut
            logger.info("Successfully updated Quick Overlay shortcut to \(newShortcut.displayString)")
            return .success(())
        } else {
            // Rollback
            GlobalShortcutManager.shared.registerQuickOverlayShortcut(
                keyCode: previous.keyCode,
                modifiers: previous.modifiers
            )
            return .failure(.registrationFailed(status))
        }
    }

    /// Validates and updates the Quick Capture shortcut, immediately applying it to GlobalShortcutManager.
    public func updateQuickCaptureShortcut(_ newShortcut: KeyCombination) -> Result<Void, ShortcutValidationError> {
        guard newShortcut.modifiers != 0 else {
            return .failure(.missingModifier)
        }

        if newShortcut == settings.quickOverlayShortcut {
            return .failure(.conflict("Quick Overlay"))
        }
        if newShortcut == settings.menuBarPanelShortcut {
            return .failure(.conflict("Menu Bar Panel"))
        }

        let previous = settings.quickCaptureShortcut
        let status = GlobalShortcutManager.shared.registerQuickCaptureShortcut(
            keyCode: newShortcut.keyCode,
            modifiers: newShortcut.modifiers
        )

        if status == 0 { // noErr
            settings.quickCaptureShortcut = newShortcut
            logger.info("Successfully updated Quick Capture shortcut to \(newShortcut.displayString)")
            return .success(())
        } else {
            // Rollback
            GlobalShortcutManager.shared.registerQuickCaptureShortcut(
                keyCode: previous.keyCode,
                modifiers: previous.modifiers
            )
            return .failure(.registrationFailed(status))
        }
    }

    /// Validates and updates the Menu Bar Panel shortcut, immediately applying it to GlobalShortcutManager.
    public func updateMenuBarPanelShortcut(_ newShortcut: KeyCombination) -> Result<Void, ShortcutValidationError> {
        guard newShortcut.modifiers != 0 else {
            return .failure(.missingModifier)
        }

        if newShortcut == settings.quickOverlayShortcut {
            return .failure(.conflict("Quick Overlay"))
        }
        if newShortcut == settings.quickCaptureShortcut {
            return .failure(.conflict("Quick Selection Capture"))
        }

        let previous = settings.menuBarPanelShortcut
        let status = GlobalShortcutManager.shared.registerMenuBarPanelShortcut(
            keyCode: newShortcut.keyCode,
            modifiers: newShortcut.modifiers
        )

        if status == 0 { // noErr
            settings.menuBarPanelShortcut = newShortcut
            logger.info("Successfully updated Menu Bar Panel shortcut to \(newShortcut.displayString)")
            return .success(())
        } else {
            // Rollback
            GlobalShortcutManager.shared.registerMenuBarPanelShortcut(
                keyCode: previous.keyCode,
                modifiers: previous.modifiers
            )
            return .failure(.registrationFailed(status))
        }
    }

    /// Updates the modifier used for automatic Quick Selection Capture (e.g. Command, Option, Control, Shift).
    public func updateSelectionCaptureModifier(_ modifier: SelectionModifier) {
        settings.selectionCaptureModifier = modifier
        logger.info("Updated selection capture modifier to \(modifier.rawValue) (\(modifier.displayString))")
    }

    /// Toggles whether automatic Quick Selection Capture (Command + Select) is enabled.
    public func toggleQuickSelectionCaptureEnabled() {
        settings.quickSelectionCaptureEnabled.toggle()
        logger.info("Toggled quickSelectionCaptureEnabled to \(self.settings.quickSelectionCaptureEnabled)")
    }

    /// Restores all settings to default values and re-registers default global shortcuts.
    public func restoreDefaults() {
        let defaults = AppSettings.default
        settings = defaults
        GlobalShortcutManager.shared.registerDefaultShortcuts()
        logger.info("Restored all settings to defaults.")
    }
}

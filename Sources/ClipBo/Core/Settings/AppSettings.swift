import Foundation
import AppKit
import Carbon

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

public enum FontScale: String, Codable, CaseIterable, Sendable {
    case compact = "Compact"
    case system = "System"
    case large = "Large"
    
    public var scaleFactor: Double {
        switch self {
        case .compact: return 0.9
        case .system: return 1.0
        case .large: return 1.15
        }
    }
}

public enum ContentDensity: String, Codable, CaseIterable, Sendable {
    case compact = "Compact"
    case comfortable = "Comfortable"
    
    public var verticalPadding: Double {
        switch self {
        case .compact: return 5.0
        case .comfortable: return 8.0
        }
    }
}

public enum HistoryRetention: Int, Codable, CaseIterable, Sendable {
    case unlimited = 0
    case limit100 = 100
    case limit500 = 500
    case limit1000 = 1000

    public var title: String {
        switch self {
        case .unlimited: return "Unlimited"
        case .limit100: return "100 clips"
        case .limit500: return "500 clips"
        case .limit1000: return "1,000 clips"
        }
    }
}

/// Modifiers supported for automatic Quick Selection Capture (e.g. ⌘ + Drag/Select).
public enum SelectionModifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case command = "Command"
    case option = "Option"
    case control = "Control"
    case shift = "Shift"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    public var displayString: String {
        "\(symbol) + Select"
    }

    public var eventFlags: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }

    public var carbonModifier: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        case .shift: return UInt32(shiftKey)
        }
    }
}

/// Category item configuration for built-in and user-defined custom categories.
public struct CustomCategoryItem: Codable, Identifiable, Hashable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var iconName: String
    public var isEnabled: Bool
    public let isBuiltIn: Bool

    public init(id: String = UUID().uuidString, title: String, iconName: String, isEnabled: Bool = true, isBuiltIn: Bool = false) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }

    public static let defaultBuiltInCategories: [CustomCategoryItem] = [
        CustomCategoryItem(id: "all", title: "All", iconName: "square.grid.2x2", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "text", title: "Text", iconName: "text.alignleft", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "star", title: "★ Star", iconName: "star.fill", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "code", title: "<> Code", iconName: "chevron.left.forwardslash.chevron.right", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "prompt", title: "✦ Prompt", iconName: "sparkles", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "url", title: "URL", iconName: "link", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "images", title: "Images", iconName: "photo", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "emoji", title: "😊 Emoji", iconName: "face.smiling", isEnabled: true, isBuiltIn: true),
        CustomCategoryItem(id: "collections", title: "Collections", iconName: "folder", isEnabled: true, isBuiltIn: true)
    ]
}

/// Geometry and position model for Quick Overlay resizing and multi-display position persistence.
public struct OverlayGeometry: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var originX: Double?
    public var originY: Double?

    public static let minWidth: Double = 520
    public static let minHeight: Double = 300
    public static let maxWidth: Double = 1000
    public static let maxHeight: Double = 700

    public init(
        width: Double = 600,
        height: Double = 380,
        originX: Double? = nil,
        originY: Double? = nil
    ) {
        self.width = min(max(width, Self.minWidth), Self.maxWidth)
        self.height = min(max(height, Self.minHeight), Self.maxHeight)
        self.originX = originX
        self.originY = originY
    }

    public static let defaultGeometry = OverlayGeometry(
        width: 600,
        height: 380,
        originX: nil,
        originY: nil
    )
}

/// Domain model representing all user-configurable preferences.
public struct AppSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var isMonitoring: Bool
    public var maxClipCount: Int
    public var maxHistoryAgeDays: Int
    public var pollingInterval: Double
    public var closeOverlayAfterCopy: Bool
    public var quickOverlayShortcut: KeyCombination
    public var quickCaptureShortcut: KeyCombination
    public var menuBarPanelShortcut: KeyCombination
    public var quickSelectionCaptureEnabled: Bool
    public var selectionCaptureModifier: SelectionModifier
    public var theme: AppTheme
    public var fontScale: FontScale
    public var density: ContentDensity
    public var allowURLMetadataFetching: Bool
    public var categoryOrder: [String]
    public var customCategories: [CustomCategoryItem]
    public var disabledCategoryIds: [String]
    public var overlayGeometry: OverlayGeometry

    // Legacy retention property support
    public var retention: HistoryRetention {
        get {
            HistoryRetention(rawValue: maxClipCount) ?? .unlimited
        }
        set {
            maxClipCount = newValue.rawValue
        }
    }

    public init(
        launchAtLogin: Bool = true,
        isMonitoring: Bool = true,
        maxClipCount: Int = 1000,
        maxHistoryAgeDays: Int = 30,
        pollingInterval: Double = 0.5,
        closeOverlayAfterCopy: Bool = true,
        quickOverlayShortcut: KeyCombination = .defaultQuickOverlay,
        quickCaptureShortcut: KeyCombination = .defaultQuickCapture,
        menuBarPanelShortcut: KeyCombination = .defaultMenuBarPanel,
        quickSelectionCaptureEnabled: Bool = true,
        selectionCaptureModifier: SelectionModifier = .command,
        theme: AppTheme = .system,
        fontScale: FontScale = .system,
        density: ContentDensity = .compact,
        allowURLMetadataFetching: Bool = false,
        categoryOrder: [String] = ["all", "text", "star", "code", "url", "images", "emoji", "collections"],
        customCategories: [CustomCategoryItem] = [],
        disabledCategoryIds: [String] = [],
        overlayGeometry: OverlayGeometry = .defaultGeometry
    ) {
        self.launchAtLogin = launchAtLogin
        self.isMonitoring = isMonitoring
        self.maxClipCount = maxClipCount
        self.maxHistoryAgeDays = maxHistoryAgeDays
        self.pollingInterval = pollingInterval
        self.closeOverlayAfterCopy = closeOverlayAfterCopy
        self.quickOverlayShortcut = quickOverlayShortcut
        self.quickCaptureShortcut = quickCaptureShortcut
        self.menuBarPanelShortcut = menuBarPanelShortcut
        self.quickSelectionCaptureEnabled = quickSelectionCaptureEnabled
        self.selectionCaptureModifier = selectionCaptureModifier
        self.theme = theme
        self.fontScale = fontScale
        self.density = density
        self.allowURLMetadataFetching = allowURLMetadataFetching
        self.categoryOrder = categoryOrder
        self.customCategories = customCategories
        self.disabledCategoryIds = disabledCategoryIds
        self.overlayGeometry = overlayGeometry
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        self.isMonitoring = try container.decodeIfPresent(Bool.self, forKey: .isMonitoring) ?? true
        self.maxClipCount = try container.decodeIfPresent(Int.self, forKey: .maxClipCount) ?? 1000
        self.maxHistoryAgeDays = try container.decodeIfPresent(Int.self, forKey: .maxHistoryAgeDays) ?? 30
        self.pollingInterval = try container.decodeIfPresent(Double.self, forKey: .pollingInterval) ?? 0.5
        self.closeOverlayAfterCopy = try container.decodeIfPresent(Bool.self, forKey: .closeOverlayAfterCopy) ?? true
        self.quickOverlayShortcut = try container.decodeIfPresent(KeyCombination.self, forKey: .quickOverlayShortcut) ?? .defaultQuickOverlay
        self.quickCaptureShortcut = try container.decodeIfPresent(KeyCombination.self, forKey: .quickCaptureShortcut) ?? .defaultQuickCapture
        self.menuBarPanelShortcut = try container.decodeIfPresent(KeyCombination.self, forKey: .menuBarPanelShortcut) ?? .defaultMenuBarPanel
        self.quickSelectionCaptureEnabled = try container.decodeIfPresent(Bool.self, forKey: .quickSelectionCaptureEnabled) ?? true
        self.selectionCaptureModifier = try container.decodeIfPresent(SelectionModifier.self, forKey: .selectionCaptureModifier) ?? .command
        self.theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        self.fontScale = try container.decodeIfPresent(FontScale.self, forKey: .fontScale) ?? .system
        self.density = try container.decodeIfPresent(ContentDensity.self, forKey: .density) ?? .compact
        self.allowURLMetadataFetching = try container.decodeIfPresent(Bool.self, forKey: .allowURLMetadataFetching) ?? false
        self.categoryOrder = try container.decodeIfPresent([String].self, forKey: .categoryOrder) ?? ["all", "text", "star", "code", "url", "images", "emoji", "collections"]
        self.customCategories = try container.decodeIfPresent([CustomCategoryItem].self, forKey: .customCategories) ?? []
        self.disabledCategoryIds = try container.decodeIfPresent([String].self, forKey: .disabledCategoryIds) ?? []
        self.overlayGeometry = try container.decodeIfPresent(OverlayGeometry.self, forKey: .overlayGeometry) ?? .defaultGeometry
    }

    public static var `default`: AppSettings {
        AppSettings()
    }
}

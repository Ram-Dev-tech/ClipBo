import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case appearance = "Appearance"
    case storage = "Storage"
    case privacy = "Privacy"
    case help = "Help"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "command"
        case .appearance: return "paintbrush"
        case .storage: return "cylinder.split.1x2"
        case .privacy: return "hand.raised"
        case .help: return "questionmark.circle"
        }
    }
}

/// Polished, compact native macOS Settings container view matching the Blip / ClipBo visual design specification.
public struct SettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var coordinator: AppCoordinator

    @State private var selectedTab: SettingsTab = .general
    @State private var hoveredTab: SettingsTab? = nil

    public init(
        settingsService: SettingsService,
        coordinator: AppCoordinator
    ) {
        self.settingsService = settingsService
        self.coordinator = coordinator
    }

    private var fontScale: Double {
        settingsService.settings.fontScale.scaleFactor
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Refined Top Navigation Bar with complete item-container hit area
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    let isHovered = hoveredTab == tab && !isSelected

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(ClipBoTypography.system(size: 18, weight: isSelected ? .medium : .regular, scale: fontScale))
                                .frame(height: 22)
                                .foregroundStyle(
                                    isSelected
                                        ? Color(red: 0.25, green: 0.65, blue: 1.0)
                                        : Color.primary.opacity(isHovered ? 0.9 : 0.6)
                                )
                                .shadow(
                                    color: isSelected
                                        ? Color(red: 0.15, green: 0.55, blue: 1.0).opacity(0.65)
                                        : Color.clear,
                                    radius: isSelected ? 6 : 0
                                )

                            Text(tab.rawValue)
                                .font(ClipBoTypography.caption(scale: fontScale))
                                .fontWeight(isSelected ? .semibold : .medium)
                                .foregroundStyle(
                                    isSelected
                                        ? Color.primary
                                        : Color.primary.opacity(isHovered ? 0.85 : 0.6)
                                )
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.35, blue: 0.85).opacity(0.20))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color(red: 0.20, green: 0.60, blue: 1.0).opacity(0.85), lineWidth: 1.2)
                                    }
                            } else if isHovered {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        hoveredTab = hovering ? tab : nil
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Active Tab Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        settingsService: settingsService,
                        onToggleLaunchAtLogin: { _ in
                            coordinator.toggleLaunchAtLogin()
                        }
                    )
                case .shortcuts:
                    ShortcutsSettingsView(settingsService: settingsService)
                case .appearance:
                    AppearanceSettingsView(settingsService: settingsService)
                case .storage:
                    StorageSettingsView(
                        clipCount: coordinator.recentClips.count,
                        starredCount: coordinator.recentClips.filter { $0.isStarred }.count,
                        imageCount: coordinator.recentClips.filter { $0.type == .image }.count,
                        databaseSizeBytes: coordinator.databaseFileSize(),
                        sqliteSizeBytes: coordinator.sqliteFileSize(),
                        walSizeBytes: coordinator.walFileSize(),
                        imagesSizeBytes: coordinator.imagesDirectorySize(),
                        onClearHistory: {
                            Task { await coordinator.clearAll() }
                        },
                        onClearImages: {
                            Task { await coordinator.clearAllImages() }
                        }
                    )
                case .privacy:
                    PrivacySettingsView(
                        settingsService: settingsService,
                        isAccessibilityGranted: coordinator.selectionCaptureService.isAccessibilityGranted
                    )
                case .help:
                    HelpSettingsView(settingsService: settingsService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 520)
    }
}

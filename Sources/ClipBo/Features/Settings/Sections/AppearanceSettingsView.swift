import SwiftUI

public struct AppearanceSettingsView: View {
    @ObservedObject var settingsService: SettingsService

    public init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }

    public var body: some View {
        Form {
            Section {
                // Font Scale
                Picker("Font Size", selection: $settingsService.settings.fontScale) {
                    ForEach(FontScale.allCases, id: \.self) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

                // Content Density
                Picker("Layout Density", selection: $settingsService.settings.density) {
                    ForEach(ContentDensity.allCases, id: \.self) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Typography & Density")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            } footer: {
                Text("ClipBo automatically follows your macOS system appearance (Light / Dark mode). Typography scaling applies live across the Menu Bar Panel, Quick Overlay, and Settings window.")
                    .font(ClipBoTypography.secondary)
                    .foregroundStyle(Color.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

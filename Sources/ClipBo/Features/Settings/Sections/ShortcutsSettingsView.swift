import SwiftUI
import ApplicationServices

public struct ShortcutsSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    public init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }

    public var body: some View {
        ScrollView {
            Form {
                // 1. Global Overlay & Panel Hotkeys
                Section {
                    ShortcutRecorderView(
                        title: "Open Menu Bar Panel",
                        currentShortcut: settingsService.settings.menuBarPanelShortcut,
                        onSave: { newShortcut in
                            settingsService.updateMenuBarPanelShortcut(newShortcut)
                        }
                    )

                    Divider()

                    ShortcutRecorderView(
                        title: "Open Quick Overlay",
                        currentShortcut: settingsService.settings.quickOverlayShortcut,
                        onSave: { newShortcut in
                            settingsService.updateQuickOverlayShortcut(newShortcut)
                        }
                    )
                } header: {
                    Text("Global Hotkeys")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 2. Quick Capture Section
                Section {
                    // Manual Capture
                    ShortcutRecorderView(
                        title: "Manual Quick Capture",
                        currentShortcut: settingsService.settings.quickCaptureShortcut,
                        onSave: { newShortcut in
                            settingsService.updateQuickCaptureShortcut(newShortcut)
                        }
                    )

                    Divider()

                    // Quick Selection Capture Toggle & Modifier
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { settingsService.settings.quickSelectionCaptureEnabled },
                            set: { _ in settingsService.toggleQuickSelectionCaptureEnabled() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quick Selection Capture")
                                    .font(ClipBoTypography.bodyMedium)
                                Text("Automatically capture content when selecting with a modifier key.")
                                    .font(ClipBoTypography.secondary)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        if settingsService.settings.quickSelectionCaptureEnabled {
                            HStack {
                                Text("Selection Modifier")
                                    .font(ClipBoTypography.body)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { settingsService.settings.selectionCaptureModifier },
                                    set: { newMod in settingsService.updateSelectionCaptureModifier(newMod) }
                                )) {
                                    ForEach(SelectionModifier.allCases) { mod in
                                        Text("\(mod.symbol) \(mod.rawValue) (\(mod.displayString))").tag(mod)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 170)
                            }
                            .padding(.top, 2)

                            // Status row
                            HStack {
                                Text("Status")
                                    .font(ClipBoTypography.caption)
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                if isAccessibilityGranted {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 7, height: 7)
                                        Text("Ready (\(settingsService.settings.selectionCaptureModifier.displayString))")
                                            .font(ClipBoTypography.caption)
                                            .foregroundStyle(Color.green)
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 7, height: 7)
                                        Text("Accessibility Permission Required")
                                            .font(ClipBoTypography.caption)
                                            .foregroundStyle(Color.orange)
                                        Button("Grant Permission") {
                                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.mini)
                                        .font(ClipBoTypography.caption)
                                    }
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Quick Capture")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                } footer: {
                    Text("Hold the configured modifier while selecting text or an image in another application to capture it directly into ClipBo without modifying your clipboard.")
                        .font(ClipBoTypography.secondary)
                        .foregroundStyle(Color.secondary)
                }

                // 3. Restore Defaults
                Section {
                    HStack {
                        Spacer()
                        Button("Restore Defaults") {
                            settingsService.restoreDefaults()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(ClipBoTypography.caption)
                    }
                    .padding(.vertical, 2)
                }
            }
            .formStyle(.grouped)
            .padding(10)
        }
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
        }
    }
}

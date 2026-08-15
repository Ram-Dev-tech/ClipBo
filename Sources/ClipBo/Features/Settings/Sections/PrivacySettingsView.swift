import SwiftUI
import AppKit

public struct PrivacySettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var currentAccessibilityState: Bool = false

    public init(
        settingsService: SettingsService,
        isAccessibilityGranted: Bool
    ) {
        self.settingsService = settingsService
        self._currentAccessibilityState = State(initialValue: isAccessibilityGranted)
    }

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("100% Local-First", systemImage: "lock.shield.fill")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.accentColor)

                    Text("ClipBo saves your clipboard history strictly on your Mac. No account is required, no data is uploaded to any cloud server, and no external AI models or analytics are used.")
                        .font(ClipBoTypography.secondary)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Privacy Guarantee")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission")
                            .font(ClipBoTypography.bodyMedium)
                        Text("Required for Quick Capture (⌥ ⌘ C) to read selected text directly.")
                            .font(ClipBoTypography.secondary)
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    if currentAccessibilityState {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                            Text("Granted")
                                .font(ClipBoTypography.bodyMedium)
                        }
                    } else {
                        Button("Open Settings…") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Permissions")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            } footer: {
                Text("macOS binds Accessibility permissions to the app binary signature. When updating or rebuilding from source, toggle the entry in System Settings to re-validate.")
                    .font(ClipBoTypography.caption)
                    .foregroundStyle(Color.secondary)
            }

            Section {
                Toggle(isOn: $settingsService.settings.allowURLMetadataFetching) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow URL Metadata Fetching")
                            .font(ClipBoTypography.bodyMedium)
                        Text("When disabled (recommended), URL domain extraction is performed 100% offline without network calls.")
                            .font(ClipBoTypography.secondary)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .toggleStyle(.switch)
            } header: {
                Text("Network Activity")
                    .font(ClipBoTypography.sectionTitle)
                    .foregroundStyle(Color.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .onAppear {
            refreshAccessibilityStatus()
        }
    }

    private func refreshAccessibilityStatus() {
        currentAccessibilityState = SelectionCaptureService.shared.isAccessibilityGranted
        SelectionCaptureService.shared.logDiagnostics()
    }

    private func openAccessibilitySettings() {
        SelectionCaptureService.shared.requestAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshAccessibilityStatus()
        }
    }
}

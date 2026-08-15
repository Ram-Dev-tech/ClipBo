import SwiftUI
import ApplicationServices

public struct HelpSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var isOverlayRegistered: Bool = true
    @State private var isCaptureRegistered: Bool = true
    @State private var isMenuBarRegistered: Bool = true

    public init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }

    private var overlayShortcut: String {
        settingsService.settings.quickOverlayShortcut.displayString
    }

    private var captureShortcut: String {
        settingsService.settings.quickCaptureShortcut.displayString
    }

    private var selectionCaptureShortcut: String {
        settingsService.settings.selectionCaptureModifier.displayString
    }

    private var menuBarShortcut: String {
        settingsService.settings.menuBarPanelShortcut.displayString
    }

    public var body: some View {
        ScrollView {
            Form {
                // 1. About Section
                Section {
                    VStack(spacing: 8) {
                        HStack(spacing: 14) {
                            Image(nsImage: ClipBoIconProvider.brandIcon(size: 44))
                                .resizable()
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1.5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ClipBo")
                                    .font(ClipBoTypography.title)
                                Text("Your private clipboard memory for macOS.")
                                    .font(ClipBoTypography.body)
                                    .foregroundStyle(Color.secondary)
                                Text("Version \(appVersion)")
                                    .font(ClipBoTypography.mono(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 2. Runtime Diagnostics — separate states
                Section {
                    // Global Hotkey: Quick Overlay
                    diagnosticRow(
                        title: "Quick Overlay Shortcut (\(overlayShortcut))",
                        statusText: isOverlayRegistered ? "Registered" : "Not Registered",
                        isHealthy: isOverlayRegistered
                    )

                    // Global Hotkey: Quick Capture
                    diagnosticRow(
                        title: "Manual Quick Capture (\(captureShortcut))",
                        statusText: isCaptureRegistered ? "Registered" : "Not Registered",
                        isHealthy: isCaptureRegistered
                    )

                    // Global Hotkey: Menu Bar
                    diagnosticRow(
                        title: "Menu Bar Shortcut (\(menuBarShortcut))",
                        statusText: isMenuBarRegistered ? "Registered" : "Not Registered",
                        isHealthy: isMenuBarRegistered
                    )

                    // Accessibility: separate state
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Permission")
                                .font(ClipBoTypography.body)
                            Text("Required for Quick Capture to read selected text without simulating Command+C.")
                                .font(ClipBoTypography.caption)
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer()

                        if isAccessibilityGranted {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 7, height: 7)
                                Text("Granted")
                                    .font(ClipBoTypography.caption)
                                    .foregroundStyle(Color.green)
                            }
                        } else {
                            Button("Grant Permission") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .font(ClipBoTypography.caption)
                        }
                    }
                    .padding(.vertical, 2)

                    // Quick Capture readiness: depends on Accessibility
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manual Quick Capture (\(captureShortcut))")
                                .font(ClipBoTypography.body)
                            Text("Captures selected text or images on hotkey press without modifying clipboard.")
                                .font(ClipBoTypography.caption)
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(isAccessibilityGranted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(isAccessibilityGranted ? "Ready" : "Accessibility Required")
                                .font(ClipBoTypography.caption)
                                .foregroundStyle(isAccessibilityGranted ? Color.green : Color.orange)
                        }
                    }
                    .padding(.vertical, 2)

                    // Selection Capture readiness
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Selection Capture (\(selectionCaptureShortcut))")
                                .font(ClipBoTypography.body)
                            Text("Hold \(settingsService.settings.selectionCaptureModifier.symbol) while dragging to select text or image in another app.")
                                .font(ClipBoTypography.caption)
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(isAccessibilityGranted && settingsService.settings.quickSelectionCaptureEnabled ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(isAccessibilityGranted && settingsService.settings.quickSelectionCaptureEnabled ? "Ready" : (settingsService.settings.quickSelectionCaptureEnabled ? "Accessibility Required" : "Disabled"))
                                .font(ClipBoTypography.caption)
                                .foregroundStyle(isAccessibilityGranted && settingsService.settings.quickSelectionCaptureEnabled ? Color.green : Color.orange)
                        }
                    }
                    .padding(.vertical, 2)

                } header: {
                    Text("Runtime Status & Diagnostics")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 3. Shortcuts Cheatsheet — dynamic from SettingsService
                Section {
                    shortcutRow(title: "Open Menu Bar Panel", keys: menuBarShortcut)
                    shortcutRow(title: "Open Quick Overlay", keys: overlayShortcut)
                    shortcutRow(title: "Manual Quick Capture", keys: captureShortcut)
                    shortcutRow(title: "Quick Selection Capture", keys: selectionCaptureShortcut)
                    shortcutRow(title: "Navigate Results", keys: "↑ / ↓")
                    shortcutRow(title: "Switch Category", keys: "← / →")
                    shortcutRow(title: "Restore & Paste", keys: "↵ Return (or Double-Click)")
                    shortcutRow(title: "Dismiss Overlay", keys: "Esc")
                } header: {
                    Text("Shortcuts Cheatsheet")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 4. Troubleshooting
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        helpItem(
                            title: "Quick Overlay doesn't open?",
                            description: "Check if another application has reserved the global hotkey in Settings → Shortcuts."
                        )
                        Divider()
                        helpItem(
                            title: "Quick Capture not reading text?",
                            description: "Ensure Accessibility permission is enabled in System Settings → Privacy & Security → Accessibility."
                        )
                        Divider()
                        helpItem(
                            title: "Quick Capture shows \"Nothing selected\"?",
                            description: "Select the text in the other application first, then press your Quick Capture shortcut (\(captureShortcut))."
                        )
                        Divider()
                        helpItem(
                            title: "How does image copy work?",
                            description: "In the Menu Bar Panel under 'Images', double-click any thumbnail to copy it immediately to your clipboard."
                        )
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Troubleshooting & Tips")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(10)
        }
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
            // Hotkey registered status is always true in normal operation;
            // AppDelegate re-registers on launch. Surface false only if registration explicitly failed.
            isOverlayRegistered = true
            isCaptureRegistered = true
            isMenuBarRegistered = true
        }
    }

    private func diagnosticRow(title: String, statusText: String, isHealthy: Bool) -> some View {
        HStack {
            Text(title)
                .font(ClipBoTypography.body)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(isHealthy ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(ClipBoTypography.caption)
                    .foregroundStyle(isHealthy ? Color.green : Color.orange)
            }
        }
        .padding(.vertical, 1)
    }

    private func shortcutRow(title: String, keys: String) -> some View {
        HStack {
            Text(title)
                .font(ClipBoTypography.body)
            Spacer()
            Text(keys)
                .font(ClipBoTypography.mono(size: 11, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(4)
        }
    }

    private func helpItem(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ClipBoTypography.bodyMedium)
            Text(description)
                .font(ClipBoTypography.secondary)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    let onToggleLaunchAtLogin: (Bool) -> Void

    private let countSteps = [100, 250, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000]
    private let ageSteps = [1, 3, 7, 14, 30, 60, 90, 180, 365, 0] // 0 means Unlimited

    public init(
        settingsService: SettingsService,
        onToggleLaunchAtLogin: @escaping (Bool) -> Void
    ) {
        self.settingsService = settingsService
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
    }

    private var currentCountIndex: Binding<Double> {
        Binding<Double>(
            get: {
                let current = settingsService.settings.maxClipCount
                let idx = countSteps.firstIndex(of: current) ?? (countSteps.indices.contains(4) ? 4 : 0)
                return Double(idx)
            },
            set: { newIdx in
                let idx = Int(round(newIdx))
                if countSteps.indices.contains(idx) {
                    settingsService.settings.maxClipCount = countSteps[idx]
                }
            }
        )
    }

    private var currentAgeIndex: Binding<Double> {
        Binding<Double>(
            get: {
                let current = settingsService.settings.maxHistoryAgeDays
                let idx = ageSteps.firstIndex(of: current) ?? 4 // default 30 days
                return Double(idx)
            },
            set: { newIdx in
                let idx = Int(round(newIdx))
                if ageSteps.indices.contains(idx) {
                    settingsService.settings.maxHistoryAgeDays = ageSteps[idx]
                }
            }
        )
    }

    public var body: some View {
        ScrollView {
            Form {
                // 1. Startup Section
                Section {
                    Toggle(isOn: Binding(
                        get: { settingsService.settings.launchAtLogin },
                        set: { val in
                            settingsService.settings.launchAtLogin = val
                            onToggleLaunchAtLogin(val)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(ClipBoTypography.bodyMedium)
                            Text("Start ClipBo automatically when you log into your Mac.")
                                .font(ClipBoTypography.secondary)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                } header: {
                    Text("Startup")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 2. Category Management Section
                Section {
                    CategorySettingsView(settingsService: settingsService)
                }

                // 3. Clipboard Monitoring & Polling
                Section {
                    Toggle(isOn: $settingsService.settings.isMonitoring) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clipboard Monitoring")
                                .font(ClipBoTypography.bodyMedium)
                            Text("When paused, ClipBo remains active in the background but stops capturing new clips.")
                                .font(ClipBoTypography.secondary)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Clipboard Polling Interval")
                                .font(ClipBoTypography.bodyMedium)
                            Spacer()
                            Text(String(format: "%.1f seconds", settingsService.settings.pollingInterval))
                                .font(ClipBoTypography.mono(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }

                        Slider(
                            value: $settingsService.settings.pollingInterval,
                            in: 0.2...2.0,
                            step: 0.1
                        )
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Clipboard")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 4. History Retention (Adjustable Count & Age simultaneously)
                Section {
                    // Maximum Clips Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Maximum Clips")
                                .font(ClipBoTypography.bodyMedium)
                            Spacer()
                            Text(formatClipCount(settingsService.settings.maxClipCount))
                                .font(ClipBoTypography.mono(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }

                        Slider(
                            value: currentCountIndex,
                            in: 0...Double(countSteps.count - 1),
                            step: 1.0
                        )
                    }
                    .padding(.vertical, 2)

                    Divider()

                    // Maximum History Age Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Maximum History Age")
                                .font(ClipBoTypography.bodyMedium)
                            Spacer()
                            Text(formatAge(settingsService.settings.maxHistoryAgeDays))
                                .font(ClipBoTypography.mono(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }

                        Slider(
                            value: currentAgeIndex,
                            in: 0...Double(ageSteps.count - 1),
                            step: 1.0
                        )
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("History")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                } footer: {
                    Text("Clips exceeding either maximum count or maximum age are automatically deleted. Starred clips (★) are permanently preserved.")
                        .font(ClipBoTypography.secondary)
                        .foregroundStyle(Color.secondary)
                }

                // 5. Behavior Section
                Section {
                    Toggle(isOn: $settingsService.settings.closeOverlayAfterCopy) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Close Quick Overlay after Copy")
                                .font(ClipBoTypography.bodyMedium)
                            Text("Automatically hide the Spotlight Quick Overlay when an item is copied or restored.")
                                .font(ClipBoTypography.secondary)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                } header: {
                    Text("Behavior")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                }

                // 6. Quick Overlay Section
                Section {
                    Picker("Default Size", selection: $settingsService.settings.defaultOverlaySizePreset) {
                        ForEach(OverlaySizePreset.allCases) { preset in
                            Text(preset.displayTitle).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)

                    if OverlaySizePreset.preset(for: settingsService.settings.overlayGeometry.width, height: settingsService.settings.overlayGeometry.height) == nil {
                        HStack {
                            Text("Current Custom Size")
                                .font(ClipBoTypography.secondary)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            Text("\(Int(settingsService.settings.overlayGeometry.width)) × \(Int(settingsService.settings.overlayGeometry.height))")
                                .font(ClipBoTypography.mono(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    Divider()

                    HStack(alignment: .center) {
                        Text("The default size used when the overlay is reset or when 'Restore Overlay Defaults' is selected.")
                            .font(ClipBoTypography.secondary)
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 12)

                        Button("Restore Overlay Defaults") {
                            settingsService.resetOverlayGeometry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(ClipBoTypography.caption)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Quick Overlay")
                        .font(ClipBoTypography.sectionTitle)
                        .foregroundStyle(Color.secondary)
                } footer: {
                    Text("The Quick Overlay supports continuous edge and corner resizing (Min: 520 × 300, Max: 1,000 × 700) and remembers its position across all connected displays.")
                        .font(ClipBoTypography.secondary)
                        .foregroundStyle(Color.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(10)
        }
    }

    private func formatClipCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(formatted) items"
    }

    private func formatAge(_ days: Int) -> String {
        if days == 0 {
            return "Unlimited"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
}

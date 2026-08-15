import SwiftUI
import AppKit
import Carbon

/// Interactive AppKit-backed keyboard shortcut recorder that captures modifiers + key codes safely.
public struct ShortcutRecorderView: View {
    public let title: String
    public let currentShortcut: KeyCombination
    public let onSave: (KeyCombination) -> Result<Void, ShortcutValidationError>

    @State private var isRecording: Bool = false
    @State private var errorMessage: String? = nil
    @State private var eventMonitor: Any? = nil

    public init(
        title: String,
        currentShortcut: KeyCombination,
        onSave: @escaping (KeyCombination) -> Result<Void, ShortcutValidationError>
    ) {
        self.title = title
        self.currentShortcut = currentShortcut
        self.onSave = onSave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(ClipBoTypography.bodyMedium)
                    .foregroundStyle(Color.primary)

                Spacer()

                if isRecording {
                    HStack(spacing: 6) {
                        Text("Press new shortcut...")
                            .font(ClipBoTypography.secondary)
                            .foregroundStyle(Color.accentColor)

                        Button("Cancel") {
                            stopRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .font(ClipBoTypography.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(currentShortcut.displayString)
                            .font(ClipBoTypography.code)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(5)

                        Button("Change") {
                            startRecording()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(ClipBoTypography.caption)
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(ClipBoTypography.secondary)
                    .foregroundStyle(Color.red)
                    .transition(.opacity)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        errorMessage = nil
        isRecording = true

        // Install local key event monitor only during active recording
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
            return nil // Consume event while recording so it does not trigger global shortcuts
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        // Convert NSEvent modifier flags to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        // Require at least one modifier
        guard carbonModifiers != 0 else {
            errorMessage = "Shortcut must include at least one modifier key (⌘, ⌥, ⌃, or ⇧)."
            return
        }

        let keyCode = UInt32(event.keyCode)
        let combination = KeyCombination(keyCode: keyCode, modifiers: carbonModifiers)

        // Attempt to save through validation callback
        let result = onSave(combination)
        switch result {
        case .success:
            errorMessage = nil
            stopRecording()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

import Foundation
import Carbon
import ClipBo

public struct ShortcutDiagnostics {
    public static func runDiagnostics() {
        print("🔍 Running Global Shortcut Registration Diagnostics...")

        let manager = GlobalShortcutManager.shared
        
        // Test registering Quick Overlay (⌘ ⇧ V)
        manager.registerQuickOverlayShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
        
        // Test registering Quick Capture (⌥ ⌘ C)
        manager.registerQuickCaptureShortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey))

        print("  Keycodes: kVK_ANSI_V = \(kVK_ANSI_V) (0x09), kVK_ANSI_C = \(kVK_ANSI_C) (0x08)")
        print("  Modifiers: cmdKey = \(cmdKey), shiftKey = \(shiftKey), optionKey = \(optionKey)")
        print("  cmdKey | shiftKey = \(cmdKey | shiftKey)")
        print("  cmdKey | optionKey = \(cmdKey | optionKey)")
    }
}

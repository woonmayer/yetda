import AppKit
import ApplicationServices
import CoreGraphics

/// The two macOS privacy permissions Yetda depends on.
/// - Screen Recording: `screencapture` needs it; without it captures come out
///   blank (wallpaper only).
/// - Accessibility: posting the paste keystroke (auto-paste) and watching for ⌘⌘.
enum Permissions {
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt (macOS shows it at most once per app).
    static func requestScreenRecording() { CGRequestScreenCaptureAccess() }

    /// Whether Accessibility permission is granted right now. With
    /// `prompt: true`, also shows the system prompt if it isn't.
    @discardableResult
    static func hasAccessibility(prompt: Bool = false) -> Bool {
        // The value of `kAXTrustedCheckOptionPrompt`, spelled out because the
        // imported global isn't concurrency-safe in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    @MainActor
    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @MainActor
    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

import AppKit
import YetdaCore

/// Fires `onDoubleTap` when ⌘ is tapped twice on its own, from any app.
/// Global key monitoring needs Accessibility permission (the same one
/// auto-paste uses); without it the monitor simply never fires.
@MainActor
final class DoubleCommandMonitor {
    private let onDoubleTap: @MainActor () -> Void
    private var detector = DoubleTapDetector()
    private var previousFlags: NSEvent.ModifierFlags = []
    private var monitor: Any?

    init(onDoubleTap: @escaping @MainActor () -> Void) {
        self.onDoubleTap = onDoubleTap
    }

    func start() {
        guard monitor == nil else { return }
        let events: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            // Global monitors are called on the main thread.
            MainActor.assumeIsolated { self?.handle(event) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        detector = DoubleTapDetector()
        previousFlags = []
    }

    private func handle(_ event: NSEvent) {
        guard let input = input(for: event) else { return }
        if detector.handle(input, at: event.timestamp) {
            onDoubleTap()
        }
    }

    /// Maps an event onto the detector's inputs; nil means "ignore".
    private func input(for event: NSEvent) -> DoubleTapDetector.Input? {
        guard event.type == .flagsChanged else { return .other } // a key or click in between
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        defer { previousFlags = flags }
        switch flags {
        case [.command]: return previousFlags.isEmpty ? .down : nil // ignore the other ⌘ joining in
        case []: return .up
        default: return .other
        }
    }
}

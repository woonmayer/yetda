import Foundation

/// Watches the capture folder for files being added or removed (by a
/// capture, the /shots skill, or Clear) and calls `onChange`, so the menu bar
/// badge stays live. Restart it (`stop()`, `start()`) if the folder is
/// recreated: it watches the directory it was started on.
@MainActor
final class CaptureFolderMonitor {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        guard source == nil else { return }
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            NSLog("Yetda: cannot watch \(url.path); the badge won't update until relaunch.")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.onChange() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

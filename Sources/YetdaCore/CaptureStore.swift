import Foundation

/// The `~/Yetda/` capture folder: naming, listing, expiry, and cleanup.
/// Only files that match Yetda's own naming scheme count as captures, so
/// anything else a user drops in the folder is never listed or deleted.
public struct CaptureStore: Sendable {
    public let folderURL: URL
    public let retentionDays: Int

    public init(folderURL: URL? = nil, retentionDays: Int = 7) {
        self.folderURL = folderURL
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Yetda", isDirectory: true)
        self.retentionDays = retentionDays
    }

    // yyyy-MM-dd-HHmmss with optional -SSS (older builds wrote no millis).
    private static let namePattern = #"^\d{4}-\d{2}-\d{2}-\d{6}(-\d{3})?\.png$"#

    public func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HHmmss-SSS"
        return formatter.string(from: date) + ".png"
    }

    public func fileURL(for date: Date) -> URL {
        folderURL.appendingPathComponent(filename(for: date))
    }

    /// Where a new capture is written until it has been scanned, so an
    /// unmasked image never sits in the folder that the badge, Paste Recent
    /// and `/shots` read. Same volume, so moving it in is atomic.
    public var pendingFolderURL: URL {
        folderURL.appendingPathComponent(".pending", isDirectory: true)
    }

    public func pendingFileURL(for date: Date) -> URL {
        pendingFolderURL.appendingPathComponent(filename(for: date))
    }

    /// Deletes leftovers from captures that were never finished (e.g. a crash mid-scan).
    public func clearPending() {
        try? FileManager.default.removeItem(at: pendingFolderURL)
    }

    public func isExpired(modificationDate: Date, now: Date) -> Bool {
        now.timeIntervalSince(modificationDate) > Double(retentionDays) * 86_400
    }

    public func isCaptureFile(_ url: URL) -> Bool {
        url.lastPathComponent.range(of: Self.namePattern, options: .regularExpression) != nil
    }

    /// All captures in the folder, newest first. Single source for the badge
    /// count, Clear, prune, and Paste Recent so they never drift.
    public func captureFiles() -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }
        // Timestamp names sort chronologically (a pre-millis name lands next
        // to same-second millis names, which is close enough).
        return entries
            .filter(isCaptureFile)
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Creates the capture folder and its pending folder if they're missing.
    public func createFolder() throws {
        try FileManager.default.createDirectory(at: pendingFolderURL, withIntermediateDirectories: true)
    }

    /// Deletes captures older than `retentionDays`.
    public func prune(now: Date = Date()) {
        for url in captureFiles() {
            guard let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate else { continue }
            if isExpired(modificationDate: modDate, now: now) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    public func removeAll() {
        for url in captureFiles() {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

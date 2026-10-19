import XCTest
@testable import YetdaCore

final class CaptureStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("yetda-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int, ms: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
        return date.addingTimeInterval(Double(ms) / 1000)
    }

    @discardableResult
    private func touch(_ name: String, modified: Date = Date()) throws -> URL {
        let url = tmp.appendingPathComponent(name)
        try Data([0]).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    func test_filename_is_utc_timestamp_with_millis_png() {
        let store = CaptureStore(folderURL: tmp)
        let date = utcDate(2026, 6, 22, 14, 30, 5, ms: 42)
        XCTAssertEqual(store.filename(for: date), "2026-06-22-143005-042.png")
    }

    func test_fileURL_is_folder_plus_filename() {
        let store = CaptureStore(folderURL: tmp)
        let date = utcDate(2026, 6, 22, 14, 30, 5)
        XCTAssertEqual(store.fileURL(for: date), tmp.appendingPathComponent("2026-06-22-143005-000.png"))
    }

    func test_default_folder_is_home_yetda() {
        let store = CaptureStore()
        XCTAssertEqual(store.folderURL.lastPathComponent, "Yetda")
    }

    func test_isExpired_boundaries() {
        let store = CaptureStore(folderURL: tmp, retentionDays: 7)
        let now = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertFalse(store.isExpired(modificationDate: now.addingTimeInterval(-6 * 86_400), now: now))
        XCTAssertTrue(store.isExpired(modificationDate: now.addingTimeInterval(-8 * 86_400), now: now))
    }

    func test_isCaptureFile_only_yetda_names() {
        let store = CaptureStore(folderURL: tmp)
        XCTAssertTrue(store.isCaptureFile(tmp.appendingPathComponent("2026-06-22-143005-042.png")))
        XCTAssertTrue(store.isCaptureFile(tmp.appendingPathComponent("2026-06-22-143005.png"))) // pre-millis
        XCTAssertFalse(store.isCaptureFile(tmp.appendingPathComponent("my-diagram.png")))
        XCTAssertFalse(store.isCaptureFile(tmp.appendingPathComponent(".shots-cache.json")))
        XCTAssertFalse(store.isCaptureFile(tmp.appendingPathComponent("note.txt")))
    }

    func test_captureFiles_are_newest_first_and_skip_foreign_files() throws {
        let store = CaptureStore(folderURL: tmp)
        try touch("2026-06-22-143005-000.png")
        try touch("2026-06-23-090000-000.png")
        try touch("my-diagram.png")
        XCTAssertEqual(store.captureFiles().map(\.lastPathComponent),
                       ["2026-06-23-090000-000.png", "2026-06-22-143005-000.png"])
    }

    func test_prune_removes_only_expired_captures() throws {
        let store = CaptureStore(folderURL: tmp, retentionDays: 7)
        let now = Date()
        try touch("2026-06-01-000000-000.png", modified: now.addingTimeInterval(-8 * 86_400))
        try touch("2026-06-20-000000-000.png", modified: now.addingTimeInterval(-1 * 86_400))
        try touch("my-diagram.png", modified: now.addingTimeInterval(-30 * 86_400))
        store.prune(now: now)
        let left = try FileManager.default.contentsOfDirectory(atPath: tmp.path).sorted()
        XCTAssertEqual(left, ["2026-06-20-000000-000.png", "my-diagram.png"])
    }

    func test_pending_captures_are_not_listed_until_moved_in() throws {
        let store = CaptureStore(folderURL: tmp)
        try store.createFolder()
        let date = utcDate(2026, 6, 22, 14, 30, 5)
        let pending = store.pendingFileURL(for: date)
        try Data([0]).write(to: pending)
        XCTAssertEqual(store.captureFiles(), [])
        try FileManager.default.moveItem(at: pending, to: store.fileURL(for: date))
        XCTAssertEqual(store.captureFiles().map(\.lastPathComponent), ["2026-06-22-143005-000.png"])
    }

    func test_clearPending_removes_leftovers() throws {
        let store = CaptureStore(folderURL: tmp)
        try store.createFolder()
        try Data([0]).write(to: store.pendingFileURL(for: Date()))
        store.clearPending()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.pendingFolderURL.path))
    }

    func test_removeAll_leaves_foreign_files() throws {
        let store = CaptureStore(folderURL: tmp)
        try touch("2026-06-20-000000-000.png")
        try touch("my-diagram.png")
        store.removeAll()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tmp.path), ["my-diagram.png"])
    }
}

import XCTest
@testable import YetdaCore

final class CaptureServiceTests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        var arguments: [String] = []
    }

    func test_arguments_are_interactive_to_file() {
        XCTAssertEqual(CaptureService.arguments(forOutputPath: "/tmp/a.png"), ["-i", "/tmp/a.png"])
        XCTAssertEqual(CaptureService.executablePath, "/usr/sbin/screencapture")
    }

    func test_zero_exit_with_a_file_is_captured_and_forwards_path() {
        let recorder = Recorder()
        let service = CaptureService(run: { recorder.arguments = $0; return 0 }, fileExists: { _ in true })
        XCTAssertEqual(service.capture(toFile: "/tmp/a.png"), .captured)
        XCTAssertEqual(recorder.arguments, ["-i", "/tmp/a.png"])
    }

    func test_nonzero_exit_is_cancelled() {
        let service = CaptureService(run: { _ in 1 }, fileExists: { _ in true })
        XCTAssertEqual(service.capture(toFile: "/tmp/a.png"), .cancelled)
    }

    func test_launch_failure_is_failed() {
        let service = CaptureService(run: { _ in CaptureService.launchFailure }, fileExists: { _ in true })
        XCTAssertEqual(service.capture(toFile: "/tmp/a.png"), .failed)
    }

    func test_zero_exit_without_a_file_is_cancelled() {
        let service = CaptureService(run: { _ in 0 }, fileExists: { _ in false })
        XCTAssertEqual(service.capture(toFile: "/tmp/a.png"), .cancelled)
    }
}

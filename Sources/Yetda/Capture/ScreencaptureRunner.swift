import Foundation
import YetdaCore

/// Launches the system `screencapture` binary, waits for it, and returns its
/// exit code, or `CaptureService.launchFailure` if it could not be launched.
/// Blocks: call off the main actor.
@Sendable
func runScreencapture(_ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CaptureService.executablePath)
    process.arguments = arguments
    do {
        try process.run()
    } catch {
        NSLog("Yetda: could not launch screencapture: \(error.localizedDescription)")
        return CaptureService.launchFailure
    }
    process.waitUntilExit()
    return process.terminationStatus
}

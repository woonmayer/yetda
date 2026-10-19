import AppKit
import YetdaCore

/// Installs the bundled `/shots` skill into coding agents' skill folders,
/// only when the user asks (once at first launch, or from the menu). It only
/// ever touches `<skills>/shots/`, keeps its own copies up to date, and never
/// overwrites or deletes a copy the user edited.
@MainActor
enum SkillInstaller {
    struct Agent {
        let name: String
        /// Exists when the agent is installed.
        let marker: URL
        let skillFile: URL

        var isPresent: Bool { FileManager.default.fileExists(atPath: marker.path) }
    }

    enum InstallError: LocalizedError {
        case editedByUser(URL)

        var errorDescription: String? {
            switch self {
            case .editedByUser(let url): "\(url.path) was edited, so Yetda leaves it alone"
            }
        }
    }

    static let agents: [Agent] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Agent(
                name: "Claude Code",
                marker: home.appendingPathComponent(".claude"),
                skillFile: home.appendingPathComponent(".claude/skills/shots/SKILL.md")
            ),
            // Codex reads user skills from ~/.agents/skills (the Agent Skills convention).
            Agent(
                name: "Codex",
                marker: home.appendingPathComponent(".codex"),
                skillFile: home.appendingPathComponent(".agents/skills/shots/SKILL.md")
            ),
        ]
    }()

    /// The skill shipped inside Yetda.app; nil when running unbundled (`swift run`).
    static let bundledSkill: Data? = Bundle.main
        .url(forResource: "SKILL", withExtension: "md", subdirectory: "skills/shots")
        .flatMap { try? Data(contentsOf: $0) }

    static var presentAgents: [Agent] {
        bundledSkill == nil ? [] : agents.filter(\.isPresent)
    }

    static func state(of agent: Agent) -> SkillInstallState {
        guard let bundled = bundledSkill else { return .notInstalled }
        return SkillInstallState(
            installed: try? Data(contentsOf: agent.skillFile),
            bundled: bundled,
            lastWrittenDigest: Settings.skillDigests[agent.skillFile.path]
        )
    }

    static func install(for agent: Agent) throws {
        guard let bundled = bundledSkill else { return }
        guard state(of: agent) != .modified else { throw InstallError.editedByUser(agent.skillFile) }
        try FileManager.default.createDirectory(
            at: agent.skillFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try bundled.write(to: agent.skillFile, options: .atomic)
        Settings.skillDigests[agent.skillFile.path] = SkillInstallState.digest(bundled)
    }

    static func uninstall(for agent: Agent) throws {
        switch state(of: agent) {
        case .notInstalled: return
        case .modified: throw InstallError.editedByUser(agent.skillFile)
        case .upToDate, .outdated: break
        }
        let fm = FileManager.default
        try fm.removeItem(at: agent.skillFile)
        let folder = agent.skillFile.deletingLastPathComponent()
        if (try? fm.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
            try? fm.removeItem(at: folder)
        }
        Settings.skillDigests[agent.skillFile.path] = nil
    }

    /// Brings copies Yetda installed up to date with this version of the app.
    static func updateInstalledCopies() {
        for agent in presentAgents where state(of: agent) == .outdated {
            do {
                try install(for: agent)
            } catch {
                NSLog("Yetda: could not update the /shots skill for \(agent.name): \(error.localizedDescription)")
            }
        }
    }

    /// Asks once, on first launch, whether to install the skill for the
    /// agents found on this Mac. Never installs without asking.
    static func offerOnce() {
        guard !Settings.skillOfferShown else { return }
        let candidates = presentAgents.filter { state(of: $0) == .notInstalled }
        guard !candidates.isEmpty else { return }
        Settings.skillOfferShown = true

        let alert = NSAlert()
        alert.messageText = "Add the /shots skill?"
        alert.informativeText = """
            With /shots, \(candidates.map(\.name).formatted(.list(type: .and))) can read every \
            capture waiting in ~/Yetda at once. Yetda adds one file:

            \(candidates.map { "~/" + relativeToHome($0.skillFile) }.joined(separator: "\n"))

            You can remove it anytime from the menu (/shots Skill).
            """
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for agent in candidates {
            do {
                try install(for: agent)
            } catch {
                NSLog("Yetda: could not install the /shots skill for \(agent.name): \(error.localizedDescription)")
            }
        }
    }

    private static func relativeToHome(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home + "/") ? String(url.path.dropFirst(home.count + 1)) : url.path
    }
}

import Foundation

public enum CodexLocator {
    public static func executableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL? {
        executableCandidates(environment: environment, homeDirectory: homeDirectory)
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public static func executableCandidates(
        environment: [String: String],
        homeDirectory: String
    ) -> [URL] {
        let candidateApps = [
            "/Applications/Codex.app",
            URL(fileURLWithPath: homeDirectory, isDirectory: true)
                .appendingPathComponent("Applications/Codex.app").path
        ]

        var candidates = candidateApps.map {
            URL(fileURLWithPath: $0)
                .appendingPathComponent("Contents/Resources/codex")
        }

        // Codex Desktop now installs its managed standalone CLI here. A Finder-launched
        // app has a minimal PATH, so it must not rely on shell startup files exposing it.
        let userDirectory = URL(fileURLWithPath: homeDirectory, isDirectory: true)
        candidates += [
            userDirectory.appendingPathComponent(".codex/packages/standalone/current/bin/codex"),
            userDirectory.appendingPathComponent(".local/bin/codex")
        ]

        let pathDirectories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let fallbackDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]

        var seenDirectories = Set<String>()
        for directory in pathDirectories + fallbackDirectories where seenDirectories.insert(directory).inserted {
            candidates.append(URL(fileURLWithPath: directory).appendingPathComponent("codex"))
        }

        var seenPaths = Set<String>()
        return candidates.filter { seenPaths.insert($0.path).inserted }
    }
}

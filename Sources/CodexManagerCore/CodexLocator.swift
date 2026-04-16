import Foundation

public enum CodexLocator {
    public static func executableURL() -> URL? {
        let candidateApps = [
            "/Applications/Codex.app",
            NSString(string: "~/Applications/Codex.app").expandingTildeInPath
        ]

        for appPath in candidateApps {
            let bundled = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/codex")
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
        for directory in path.split(separator: ":").map(String.init) {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("codex")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}

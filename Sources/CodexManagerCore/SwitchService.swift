import AppKit
import Foundation

public final class SwitchService {
    private let authFileManager: AuthFileManager

    public init(authFileManager: AuthFileManager = AuthFileManager()) {
        self.authFileManager = authFileManager
    }

    public func switchToProfile(
        _ profile: ManagedProfile,
        currentActiveProfile: ManagedProfile?,
        restartCodexDesktop: Bool
    ) throws {
        try authFileManager.activate(profile: profile, currentActiveProfile: currentActiveProfile)

        if restartCodexDesktop {
            ProcessUtilities.restartCodexDesktop()
        }
    }
}

public enum ProcessUtilities {
    private static let codexBundleIdentifiers = ["com.openai.codex", "com.openai.Codex"]

    public static func isCodexDesktopRunning() -> Bool {
        !runningCodexDesktopApplications().isEmpty ||
        shellExitCode("/usr/bin/pgrep", ["-x", "Codex"]) == 0 ||
        hasCodexAppBundleProcesses()
    }

    public static func hasCodexTerminalProcesses() -> Bool {
        shellExitCode("/usr/bin/pgrep", ["-f", "/codex( exec|$)|codex exec|codex$"]) == 0
    }

    public static func restartCodexDesktop() {
        let applicationURL = codexDesktopApplicationURL()
        DispatchQueue.global(qos: .userInitiated).async {
            quitCodexDesktop()

            if !waitForCodexDesktopToExit(timeout: 5.0) {
                forceQuitCodexDesktop()
                _ = waitForCodexDesktopToExit(timeout: 2.0)
            }

            openCodexDesktop(at: applicationURL)
        }
    }

    public static func quitCodexDesktop() {
        for app in runningCodexDesktopApplications() {
            app.terminate()
        }
        _ = shellExitCode("/usr/bin/osascript", ["-e", "tell application \"Codex\" to quit"])
    }

    public static func openCodexDesktop(at applicationURL: URL? = nil) {
        if let applicationURL {
            if shellExitCode("/usr/bin/open", [applicationURL.path]) == 0 {
                return
            }
        }

        for bundleIdentifier in codexBundleIdentifiers {
            if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                if shellExitCode("/usr/bin/open", [applicationURL.path]) == 0 {
                    return
                }
            }
        }

        _ = shellExitCode("/usr/bin/open", ["-a", "Codex"])
    }

    @discardableResult
    public static func shellExitCode(_ launchPath: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return 127
        }
    }

    private static func runningCodexDesktopApplications() -> [NSRunningApplication] {
        codexBundleIdentifiers.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
    }

    private static func forceQuitCodexDesktop() {
        for app in runningCodexDesktopApplications() {
            app.forceTerminate()
        }
        _ = shellExitCode("/usr/bin/pkill", ["-x", "Codex"])
        _ = shellExitCode("/usr/bin/pkill", ["-f", "/Codex\\.app/Contents/(MacOS/Codex|Frameworks/.*Codex Helper|Resources/codex app-server)"])
    }

    private static func waitForCodexDesktopToExit(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isCodexDesktopRunning() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return !isCodexDesktopRunning()
    }

    private static func codexDesktopApplicationURL() -> URL? {
        if let bundleURL = runningCodexDesktopApplications().compactMap(\.bundleURL).first {
            return bundleURL
        }

        for bundleIdentifier in codexBundleIdentifiers {
            if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return applicationURL
            }
        }

        let fileManager = FileManager.default
        let candidatePaths = [
            "/Applications/Codex.app",
            NSString(string: "~/Applications/Codex.app").expandingTildeInPath
        ]

        return candidatePaths
            .map(URL.init(fileURLWithPath:))
            .first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    private static func hasCodexAppBundleProcesses() -> Bool {
        shellExitCode(
            "/usr/bin/pgrep",
            ["-f", "/Codex\\.app/Contents/(MacOS/Codex|Frameworks/.*Codex Helper|Resources/codex app-server)"]
        ) == 0
    }
}

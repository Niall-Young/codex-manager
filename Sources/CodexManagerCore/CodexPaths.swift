import Foundation

public struct CodexPaths {
    public var applicationSupportDirectory: URL
    public var profilesDirectory: URL
    public var temporaryProfilesDirectory: URL
    public var databaseURL: URL
    public var currentCodexHome: URL

    public init(
        applicationSupportDirectory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Codex Manager", isDirectory: true),
        currentCodexHome: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.profilesDirectory = applicationSupportDirectory.appendingPathComponent("Profiles", isDirectory: true)
        self.temporaryProfilesDirectory = applicationSupportDirectory.appendingPathComponent("TemporaryProfiles", isDirectory: true)
        self.databaseURL = applicationSupportDirectory.appendingPathComponent("profiles.json")
        self.currentCodexHome = currentCodexHome
    }

    public func profileCodexHome(profileID: String) -> URL {
        profilesDirectory
            .appendingPathComponent(profileID, isDirectory: true)
            .appendingPathComponent("codex-home", isDirectory: true)
    }

    public func temporaryCodexHome(profileID: String) -> URL {
        temporaryProfilesDirectory
            .appendingPathComponent(profileID, isDirectory: true)
            .appendingPathComponent("codex-home", isDirectory: true)
    }

    public func authFile(in codexHome: URL) -> URL {
        codexHome.appendingPathComponent("auth.json")
    }

    public var currentAuthFile: URL {
        authFile(in: currentCodexHome)
    }
}

public enum FileSecurity {
    public static func ensurePrivateDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        chmod(url.path, 0o700)
    }

    public static func ensurePrivateFile(_ url: URL) {
        chmod(url.path, 0o600)
    }
}

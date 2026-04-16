import CryptoKit
import Foundation

public final class AuthFileManager {
    private let paths: CodexPaths
    private let fileManager: FileManager

    public init(paths: CodexPaths = CodexPaths(), fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func accountIDHash(codexHome: URL) throws -> String? {
        let authURL = paths.authFile(in: codexHome)
        guard fileManager.fileExists(atPath: authURL.path) else { return nil }
        let data = try Data(contentsOf: authURL)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let tokens = object?["tokens"] as? [String: Any]
        guard let accountID = tokens?["account_id"] as? String, !accountID.isEmpty else {
            return nil
        }
        let digest = SHA256.hash(data: Data(accountID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func syncCurrentAuth(to profile: ManagedProfile) throws {
        let source = paths.currentAuthFile
        guard fileManager.fileExists(atPath: source.path) else { return }
        let destinationHome = URL(fileURLWithPath: profile.codexHomePath, isDirectory: true)
        try FileSecurity.ensurePrivateDirectory(destinationHome)
        let destination = paths.authFile(in: destinationHome)
        try copyReplacing(source: source, destination: destination)
    }

    public func activate(profile: ManagedProfile, currentActiveProfile: ManagedProfile?) throws {
        if let currentActiveProfile, currentActiveProfile.id != profile.id {
            try syncCurrentAuth(to: currentActiveProfile)
        }

        let profileHome = URL(fileURLWithPath: profile.codexHomePath, isDirectory: true)
        let source = paths.authFile(in: profileHome)
        guard fileManager.fileExists(atPath: source.path) else {
            throw CodexManagerError.authFileMissing(source)
        }

        try FileSecurity.ensurePrivateDirectory(paths.currentCodexHome)
        try copyReplacing(source: source, destination: paths.currentAuthFile)
    }

    public func moveTemporaryCodexHome(_ temporaryHome: URL, to finalHome: URL) throws {
        let finalParent = finalHome.deletingLastPathComponent()
        try FileSecurity.ensurePrivateDirectory(finalParent)
        if fileManager.fileExists(atPath: finalHome.path) {
            try fileManager.removeItem(at: finalHome)
        }
        try fileManager.moveItem(at: temporaryHome, to: finalHome)
        try FileSecurity.ensurePrivateDirectory(finalHome)
        let authURL = paths.authFile(in: finalHome)
        if fileManager.fileExists(atPath: authURL.path) {
            FileSecurity.ensurePrivateFile(authURL)
        }
    }

    public func deleteCodexHome(_ codexHome: URL) throws {
        if fileManager.fileExists(atPath: codexHome.path) {
            try fileManager.removeItem(at: codexHome)
        }
    }

    private func copyReplacing(source: URL, destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw CodexManagerError.authFileMissing(source)
        }

        try FileSecurity.ensurePrivateDirectory(destination.deletingLastPathComponent())
        let temporary = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")

        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }

        try fileManager.copyItem(at: source, to: temporary)
        FileSecurity.ensurePrivateFile(temporary)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporary, to: destination)
        FileSecurity.ensurePrivateFile(destination)
    }
}

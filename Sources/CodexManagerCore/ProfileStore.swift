import Foundation

public final class ProfileStore {
    public private(set) var database: ProfileDatabase

    private let paths: CodexPaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: CodexPaths = CodexPaths()) throws {
        self.paths = paths
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try FileSecurity.ensurePrivateDirectory(paths.applicationSupportDirectory)
        try FileSecurity.ensurePrivateDirectory(paths.profilesDirectory)
        try FileSecurity.ensurePrivateDirectory(paths.temporaryProfilesDirectory)

        if FileManager.default.fileExists(atPath: paths.databaseURL.path) {
            let data = try Data(contentsOf: paths.databaseURL)
            self.database = try decoder.decode(ProfileDatabase.self, from: data)
        } else {
            self.database = ProfileDatabase()
            try save()
        }
    }

    public var profiles: [ManagedProfile] {
        database.profiles.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public var activeProfile: ManagedProfile? {
        guard let id = database.activeProfileID else { return nil }
        return database.profiles.first { $0.id == id }
    }

    public func save() throws {
        let data = try encoder.encode(database)
        try data.write(to: paths.databaseURL, options: [.atomic])
        FileSecurity.ensurePrivateFile(paths.databaseURL)
    }

    public func upsert(_ profile: ManagedProfile) throws {
        if let index = database.profiles.firstIndex(where: { $0.id == profile.id }) {
            database.profiles[index] = profile
        } else {
            database.profiles.append(profile)
        }
        try save()
    }

    public func profile(id: String) -> ManagedProfile? {
        database.profiles.first { $0.id == id }
    }

    public func profile(accountIDHash: String) -> ManagedProfile? {
        database.profiles.first { $0.accountIDHash == accountIDHash }
    }

    public func setActiveProfile(id: String?) throws {
        let now = Date()
        if let lastIndex = database.activations.lastIndex(where: { $0.endedAt == nil }) {
            database.activations[lastIndex].endedAt = now
        }
        database.activeProfileID = id
        if let id {
            database.activations.append(ProfileActivation(profileID: id, startedAt: now))
        }
        try save()
    }

    public func removeProfile(id: String) throws -> ManagedProfile {
        guard let index = database.profiles.firstIndex(where: { $0.id == id }) else {
            throw CodexManagerError.profileNotFound
        }
        let removed = database.profiles.remove(at: index)
        database.activations = database.activations.filter { $0.profileID != id }
        if database.activeProfileID == id {
            database.activeProfileID = nil
        }
        try save()
        return removed
    }

    public func activationWindows(for profileID: String) -> [ProfileActivation] {
        database.activations.filter { $0.profileID == profileID }
    }
}

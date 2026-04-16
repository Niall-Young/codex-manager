import CodexManagerCore
import Foundation

enum SelfTestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case let .assertion(message):
            return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SelfTestFailure.assertion(message)
    }
}

func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexManagerSelfTest-\(UUID().uuidString)", isDirectory: true)
}

func testStorePersistsProfilesAndActiveProfile() throws {
    let root = temporaryDirectory()
    let paths = CodexPaths(applicationSupportDirectory: root, currentCodexHome: root.appendingPathComponent("current"))
    let store = try ProfileStore(paths: paths)

    let profile = ManagedProfile(displayName: "A", codexHomePath: paths.profileCodexHome(profileID: "a").path)
    try store.upsert(profile)
    try store.setActiveProfile(id: profile.id)

    let reloaded = try ProfileStore(paths: paths)
    try expect(reloaded.profiles.count == 1, "Expected one persisted profile.")
    try expect(reloaded.activeProfile?.id == profile.id, "Expected active profile to persist.")
    try expect(reloaded.database.activations.count == 1, "Expected activation history to persist.")
}

func testRateLimitDecodePrefersCodexBucket() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "other",
        "primary": {"usedPercent": 10},
        "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
        "planType": "plus"
      },
      "rateLimitsByLimitId": {
        "codex": {
          "limitId": "codex",
          "primary": {"usedPercent": 73, "windowDurationMins": 300, "resetsAt": 1776338906},
          "secondary": {"usedPercent": 24, "windowDurationMins": 10080, "resetsAt": 1776841820},
          "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
          "planType": "plus"
        }
      }
    }
    """
    let result = try JSONDecoder().decode(RateLimitReadResult.self, from: Data(json.utf8))
    try expect(result.preferredCodexSnapshot.limitId == "codex", "Expected codex bucket to be preferred.")
    try expect(result.preferredCodexSnapshot.primary?.usedPercent == 73, "Expected primary usage to decode.")
}

func testAccountIDHashIgnoresRawAccountID() throws {
    let root = temporaryDirectory()
    let paths = CodexPaths(applicationSupportDirectory: root.appendingPathComponent("app"), currentCodexHome: root.appendingPathComponent("current"))
    let codexHome = root.appendingPathComponent("profile")
    try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
    try #"{"tokens":{"account_id":"acct_123"}}"#.data(using: .utf8)!.write(to: codexHome.appendingPathComponent("auth.json"))

    let hash = try AuthFileManager(paths: paths).accountIDHash(codexHome: codexHome)
    try expect(hash != nil, "Expected account hash.")
    try expect(hash != "acct_123", "Expected raw account id not to be stored.")
    try expect(hash?.count == 64, "Expected SHA-256 hex hash.")
}

func testFinalizeLoginRequiresCompletedAuth() throws {
    let root = temporaryDirectory()
    let paths = CodexPaths(applicationSupportDirectory: root.appendingPathComponent("app"), currentCodexHome: root.appendingPathComponent("current"))
    let temporaryHome = paths.temporaryCodexHome(profileID: "pending")
    try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)

    let service = CodexAccountService(paths: paths)
    do {
        _ = try service.finalizeLogin(
            temporaryCodexHome: temporaryHome,
            finalProfileID: "pending",
            accountInfo: AccountInfo(email: nil, planType: nil, requiresOpenAIAuth: true),
            usage: nil
        )
        try expect(false, "Expected incomplete login to be rejected.")
    } catch CodexManagerError.loginNotCompleted {
        let finalHome = paths.profileCodexHome(profileID: "pending")
        try expect(!FileManager.default.fileExists(atPath: finalHome.path), "Expected incomplete login not to be moved into Profiles.")
    }
}

func testFinalizeLoginMovesCompletedAuth() throws {
    let root = temporaryDirectory()
    let paths = CodexPaths(applicationSupportDirectory: root.appendingPathComponent("app"), currentCodexHome: root.appendingPathComponent("current"))
    let temporaryHome = paths.temporaryCodexHome(profileID: "complete")
    try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
    try #"{"tokens":{"account_id":"acct_complete"}}"#.data(using: .utf8)!.write(to: temporaryHome.appendingPathComponent("auth.json"))

    let service = CodexAccountService(paths: paths)
    let profile = try service.finalizeLogin(
        temporaryCodexHome: temporaryHome,
        finalProfileID: "complete",
        accountInfo: AccountInfo(email: "account@example.com", planType: "plus", requiresOpenAIAuth: false),
        usage: nil
    )

    try expect(profile.accountIDHash?.count == 64, "Expected completed login to store account hash.")
    try expect(profile.email == "account@example.com", "Expected completed login to preserve account email.")
    try expect(FileManager.default.fileExists(atPath: paths.profileCodexHome(profileID: "complete").path), "Expected completed login to move into Profiles.")
    try expect(!FileManager.default.fileExists(atPath: temporaryHome.path), "Expected temporary login home to be moved.")
}

let tests: [(String, () throws -> Void)] = [
    ("store persists profiles and active profile", testStorePersistsProfilesAndActiveProfile),
    ("rate limit decode prefers codex bucket", testRateLimitDecodePrefersCodexBucket),
    ("account id hash ignores raw id", testAccountIDHashIgnoresRawAccountID),
    ("finalize login requires completed auth", testFinalizeLoginRequiresCompletedAuth),
    ("finalize login moves completed auth", testFinalizeLoginMovesCompletedAuth)
]

do {
    for (name, test) in tests {
        try test()
        print("PASS \(name)")
    }
} catch {
    fputs("FAIL \(error)\n", stderr)
    exit(1)
}

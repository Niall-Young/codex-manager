import Foundation

public struct ManagedProfile: Identifiable, Codable, Equatable {
    public var id: String
    public var displayName: String
    public var email: String?
    public var planType: String?
    public var accountIDHash: String?
    public var codexHomePath: String
    public var createdAt: Date
    public var lastRefreshedAt: Date?
    public var lastUsageSnapshot: RateLimitSnapshot?
    public var lastError: String?

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        email: String? = nil,
        planType: String? = nil,
        accountIDHash: String? = nil,
        codexHomePath: String,
        createdAt: Date = Date(),
        lastRefreshedAt: Date? = nil,
        lastUsageSnapshot: RateLimitSnapshot? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.planType = planType
        self.accountIDHash = accountIDHash
        self.codexHomePath = codexHomePath
        self.createdAt = createdAt
        self.lastRefreshedAt = lastRefreshedAt
        self.lastUsageSnapshot = lastUsageSnapshot
        self.lastError = lastError
    }
}

public struct ProfileActivation: Identifiable, Codable, Equatable {
    public var id: String
    public var profileID: String
    public var startedAt: Date
    public var endedAt: Date?

    public init(
        id: String = UUID().uuidString,
        profileID: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct ProfileDatabase: Codable, Equatable {
    public var profiles: [ManagedProfile]
    public var activeProfileID: String?
    public var activations: [ProfileActivation]

    public init(
        profiles: [ManagedProfile] = [],
        activeProfileID: String? = nil,
        activations: [ProfileActivation] = []
    ) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.activations = activations
    }
}

public struct AccountInfo: Codable, Equatable {
    public var email: String?
    public var planType: String?
    public var requiresOpenAIAuth: Bool

    public init(email: String?, planType: String?, requiresOpenAIAuth: Bool) {
        self.email = email
        self.planType = planType
        self.requiresOpenAIAuth = requiresOpenAIAuth
    }
}

public struct CreditsSnapshot: Codable, Equatable {
    public var balance: String?
    public var hasCredits: Bool
    public var unlimited: Bool
}

public struct RateLimitWindow: Codable, Equatable {
    public var usedPercent: Int
    public var resetsAt: Int64?
    public var windowDurationMins: Int64?

    public var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

public struct RateLimitSnapshot: Codable, Equatable {
    public var limitId: String?
    public var limitName: String?
    public var planType: String?
    public var credits: CreditsSnapshot?
    public var primary: RateLimitWindow?
    public var secondary: RateLimitWindow?
}

public struct RateLimitReadResult: Codable, Equatable {
    public var rateLimits: RateLimitSnapshot
    public var rateLimitsByLimitId: [String: RateLimitSnapshot]?

    public var preferredCodexSnapshot: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }
}

public struct LoginStartInfo: Equatable {
    public var loginId: String
    public var userCode: String
    public var verificationURL: URL
    public var temporaryCodexHome: URL
}

public struct LocalUsageSummary: Equatable {
    public var profileID: String?
    public var tokensUsed: Int64
    public var threadCount: Int

    public init(profileID: String?, tokensUsed: Int64, threadCount: Int) {
        self.profileID = profileID
        self.tokensUsed = tokensUsed
        self.threadCount = threadCount
    }
}

public enum CodexManagerError: LocalizedError {
    case codexExecutableNotFound
    case invalidAppServerResponse(String)
    case appServerError(String)
    case profileNotFound
    case authFileMissing(URL)
    case duplicateAccount
    case unsupportedLoginResponse
    case loginNotCompleted
    case commandFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .codexExecutableNotFound:
            return "Codex executable was not found."
        case let .invalidAppServerResponse(message):
            return "Invalid Codex app-server response: \(message)"
        case let .appServerError(message):
            return message
        case .profileNotFound:
            return "Profile was not found."
        case let .authFileMissing(url):
            return "Missing auth file at \(url.path)."
        case .duplicateAccount:
            return "This account already exists."
        case .unsupportedLoginResponse:
            return "Codex returned an unsupported login response."
        case .loginNotCompleted:
            return "Login has not completed yet. No account was added."
        case let .commandFailed(message):
            return message
        case .timedOut:
            return "The operation timed out."
        }
    }
}

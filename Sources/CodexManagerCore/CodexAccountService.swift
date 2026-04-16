import Foundation

public final class CodexAccountService {
    private let paths: CodexPaths
    private let authFileManager: AuthFileManager
    private let decoder = JSONDecoder()

    public init(paths: CodexPaths = CodexPaths(), authFileManager: AuthFileManager? = nil) {
        self.paths = paths
        self.authFileManager = authFileManager ?? AuthFileManager(paths: paths)
    }

    public func startDeviceLogin(profileID: String = UUID().uuidString) async throws -> (LoginStartInfo, CodexAppServerClient) {
        let temporaryHome = paths.temporaryCodexHome(profileID: profileID)
        try FileSecurity.ensurePrivateDirectory(temporaryHome)

        let client = try CodexAppServerClient(codexHome: temporaryHome)
        try client.start()
        try await client.initialize()

        let response = try await client.request(
            method: "account/login/start",
            params: ["type": "chatgptDeviceCode"]
        )

        guard
            let type = response["type"] as? String,
            type == "chatgptDeviceCode",
            let loginId = response["loginId"] as? String,
            let userCode = response["userCode"] as? String,
            let verificationURLString = response["verificationUrl"] as? String,
            let verificationURL = URL(string: verificationURLString)
        else {
            throw CodexManagerError.unsupportedLoginResponse
        }

        return (
            LoginStartInfo(
                loginId: loginId,
                userCode: userCode,
                verificationURL: verificationURL,
                temporaryCodexHome: temporaryHome
            ),
            client
        )
    }

    public func readAccount(using client: CodexAppServerClient, refreshToken: Bool = false) async throws -> AccountInfo {
        let response = try await client.request(
            method: "account/read",
            params: ["refreshToken": refreshToken]
        )
        let requiresOpenAIAuth = response["requiresOpenaiAuth"] as? Bool ?? true
        let account = response["account"] as? [String: Any]
        return AccountInfo(
            email: account?["email"] as? String,
            planType: account?["planType"] as? String,
            requiresOpenAIAuth: requiresOpenAIAuth
        )
    }

    public func readRateLimits(using client: CodexAppServerClient) async throws -> RateLimitReadResult {
        let response = try await client.request(method: "account/rateLimits/read", params: [:])
        let data = try JSONSerialization.data(withJSONObject: response)
        return try decoder.decode(RateLimitReadResult.self, from: data)
    }

    public func readRateLimits(codexHome: URL) async throws -> RateLimitReadResult {
        let client = try CodexAppServerClient(codexHome: codexHome)
        defer { client.stop() }
        try client.start()
        try await client.initialize()
        return try await readRateLimits(using: client)
    }

    public func finalizeLogin(
        temporaryCodexHome: URL,
        finalProfileID: String,
        accountInfo: AccountInfo,
        usage: RateLimitReadResult?
    ) throws -> ManagedProfile {
        guard !accountInfo.requiresOpenAIAuth,
              let hash = try authFileManager.accountIDHash(codexHome: temporaryCodexHome) else {
            throw CodexManagerError.loginNotCompleted
        }

        let finalHome = paths.profileCodexHome(profileID: finalProfileID)
        try authFileManager.moveTemporaryCodexHome(temporaryCodexHome, to: finalHome)

        return ManagedProfile(
            id: finalProfileID,
            displayName: accountInfo.email ?? "ChatGPT Account",
            email: accountInfo.email,
            planType: accountInfo.planType,
            accountIDHash: hash,
            codexHomePath: finalHome.path,
            lastRefreshedAt: usage == nil ? nil : Date(),
            lastUsageSnapshot: usage?.preferredCodexSnapshot
        )
    }
}

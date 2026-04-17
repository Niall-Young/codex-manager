import AppKit
import CodexManagerCore
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var profiles: [ManagedProfile] = []
    @Published var activeProfile: ManagedProfile?
    @Published var currentProfileID: String?
    @Published var currentSessionProfile: ManagedProfile?
    @Published var statusMessage: String?
    @Published var localUsage = LocalUsageSummary(profileID: nil, tokensUsed: 0, threadCount: 0)
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageDefaultsKey)
        }
    }

    private let paths: CodexPaths
    private let store: ProfileStore
    private let authFileManager: AuthFileManager
    private let accountService: CodexAccountService
    private let switchService: SwitchService
    private let usageEstimator: LocalUsageEstimator
    private var refreshTimer: Timer?
    private static let languageDefaultsKey = "language"
    private static let menuBarRefreshInterval: TimeInterval = 20

    init() {
        do {
            let storedLanguage = UserDefaults.standard.string(forKey: Self.languageDefaultsKey)
            self.language = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .english
            let paths = CodexPaths()
            self.paths = paths
            self.store = try ProfileStore(paths: paths)
            self.authFileManager = AuthFileManager(paths: paths)
            self.accountService = CodexAccountService(paths: paths, authFileManager: authFileManager)
            self.switchService = SwitchService(authFileManager: authFileManager)
            self.usageEstimator = LocalUsageEstimator(paths: paths)
            cleanupIncompleteProfiles()
            cleanupTemporaryProfiles()
            reload()
            refreshCurrentSession()
            startRefreshTimer()
        } catch {
            fatalError("Failed to initialize Codex Manager: \(error.localizedDescription)")
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var profileStore: ProfileStore { store }
    var codexAccountService: CodexAccountService { accountService }
    var codexPaths: CodexPaths { paths }
    var strings: Strings { Strings(language: language) }
    var displayedCurrentProfile: ManagedProfile? { currentSessionProfile ?? activeProfile }
    var menuBarQuotaText: String {
        guard let snapshot = displayedCurrentProfile?.lastUsageSnapshot else { return "--" }
        guard let window = preferredMenuBarWindow(in: snapshot) else { return "--" }
        return "\(window.remainingPercent)%"
    }

    func reload() {
        profiles = store.profiles
        activeProfile = store.activeProfile
        currentProfileID = activeProfile?.id
        localUsage = usageEstimator.estimate(
            profileID: currentProfileID,
            activations: store.database.activations
        )
    }

    func refreshCurrentSession() {
        Task {
            let currentHash = try? authFileManager.accountIDHash(codexHome: paths.currentCodexHome)
            let liveAccount = try? await readAccountForCurrentCodexHome()
            let liveUsage = try? await accountService.readRateLimits(codexHome: paths.currentCodexHome)

            let matchedProfile = currentHash.flatMap { store.profile(accountIDHash: $0) }
            if var matchedProfile {
                matchedProfile.accountIDHash = currentHash ?? matchedProfile.accountIDHash
                matchedProfile.planType = liveAccount?.planType ?? matchedProfile.planType
                if matchedProfile.email == nil, let email = liveAccount?.email {
                    matchedProfile.email = email
                    matchedProfile.displayName = email
                }
                matchedProfile.lastUsageSnapshot = liveUsage?.preferredCodexSnapshot ?? matchedProfile.lastUsageSnapshot
                matchedProfile.lastRefreshedAt = liveUsage == nil ? matchedProfile.lastRefreshedAt : Date()
                matchedProfile.lastError = nil
                try? store.upsert(matchedProfile)
                if store.database.activeProfileID != matchedProfile.id {
                    try? store.setActiveProfile(id: matchedProfile.id)
                }
                profiles = store.profiles
                activeProfile = store.profile(id: matchedProfile.id) ?? matchedProfile
                currentProfileID = matchedProfile.id
                currentSessionProfile = nil
                localUsage = usageEstimator.estimate(
                    profileID: matchedProfile.id,
                    activations: store.database.activations
                )
                return
            }

            // If the current auth hash does not belong to a managed profile,
            // never fall back to showing the last active managed account.
            activeProfile = nil
            currentProfileID = nil
            localUsage = usageEstimator.estimate(
                profileID: nil,
                activations: store.database.activations
            )

            if currentHash != nil || (liveAccount != nil && liveAccount?.requiresOpenAIAuth == false) {
                currentSessionProfile = ManagedProfile(
                    id: "current-session",
                    displayName: liveAccount?.email ?? "Current Account",
                    email: liveAccount?.email,
                    planType: liveAccount?.planType,
                    accountIDHash: currentHash,
                    codexHomePath: paths.currentCodexHome.path,
                    lastRefreshedAt: liveUsage == nil ? nil : Date(),
                    lastUsageSnapshot: liveUsage?.preferredCodexSnapshot
                )
            } else {
                currentSessionProfile = nil
            }
        }
    }

    func importCurrentAccount() {
        Task {
            do {
                let id = UUID().uuidString
                let finalHome = paths.profileCodexHome(profileID: id)
                try FileSecurity.ensurePrivateDirectory(finalHome)
                try authFileManager.syncCurrentAuth(
                    to: ManagedProfile(displayName: "Current Account", codexHomePath: finalHome.path)
                )

                let hash = try authFileManager.accountIDHash(codexHome: finalHome)
                guard let hash else {
                    statusMessage = "Current Codex login is not authenticated."
                    try authFileManager.deleteCodexHome(finalHome)
                    return
                }

                if store.profile(accountIDHash: hash) != nil {
                    statusMessage = "This account is already managed."
                    try authFileManager.deleteCodexHome(finalHome)
                    return
                }

                let account = try? await readAccountForCurrentCodexHome()
                let usage = try? await accountService.readRateLimits(codexHome: finalHome)
                var profile = ManagedProfile(
                    id: id,
                    displayName: "Current Account",
                    accountIDHash: hash,
                    codexHomePath: finalHome.path,
                    lastRefreshedAt: usage == nil ? nil : Date(),
                    lastUsageSnapshot: usage?.preferredCodexSnapshot
                )

                if let account {
                    profile.email = account.email
                    profile.planType = account.planType
                    profile.displayName = account.email ?? profile.displayName
                }

                try store.upsert(profile)
                if store.database.activeProfileID == nil {
                    try store.setActiveProfile(id: profile.id)
                }
                statusMessage = "Imported \(profile.displayName)."
                reload()
                refreshCurrentSession()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func switchToProfile(_ profile: ManagedProfile) {
        let desktopRunning = ProcessUtilities.isCodexDesktopRunning()
        let terminalRunning = ProcessUtilities.hasCodexTerminalProcesses()

        if desktopRunning || terminalRunning {
            let alert = NSAlert()
            alert.messageText = strings.text(.switchConfirmTitle)
            alert.informativeText = terminalRunning
                ? strings.text(.switchConfirmBodyTerminal)
                : strings.text(.switchConfirmBodyDesktop)
            alert.addButton(withTitle: strings.text(.restartAndSwitch))
            alert.addButton(withTitle: strings.text(.cancel))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            try switchService.switchToProfile(
                profile,
                currentActiveProfile: activeProfile,
                restartCodexDesktop: desktopRunning
            )
            try store.setActiveProfile(id: profile.id)
            statusMessage = "Switched to \(profile.displayName)."
            reload()
            refreshCurrentSession()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshUsage(for profile: ManagedProfile) {
        Task {
            do {
                let codexHome = URL(fileURLWithPath: profile.codexHomePath, isDirectory: true)
                let result = try await accountService.readRateLimits(codexHome: codexHome)
                var updated = profile
                updated.lastUsageSnapshot = result.preferredCodexSnapshot
                updated.lastRefreshedAt = Date()
                updated.lastError = nil
                try store.upsert(updated)
                reload()
                refreshCurrentSession()
            } catch {
                var updated = profile
                updated.lastError = error.localizedDescription
                try? store.upsert(updated)
                statusMessage = error.localizedDescription
                reload()
            }
        }
    }

    func deleteProfile(_ profile: ManagedProfile) {
        let alert = NSAlert()
        alert.messageText = "\(strings.text(.deleteConfirmTitle)) \(profile.displayName)"
        alert.informativeText = strings.text(.deleteConfirmBody)
        alert.addButton(withTitle: strings.text(.deleteButton))
        alert.addButton(withTitle: strings.text(.cancel))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let removed = try store.removeProfile(id: profile.id)
            try authFileManager.deleteCodexHome(URL(fileURLWithPath: removed.codexHomePath, isDirectory: true))
            statusMessage = "Deleted \(profile.displayName)."
            reload()
            refreshCurrentSession()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func renameProfile(_ profile: ManagedProfile, displayName: String) {
        var updated = profile
        updated.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if updated.displayName.isEmpty {
            updated.displayName = profile.email ?? "ChatGPT Account"
        }
        do {
            try store.upsert(updated)
            reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func openOfficialUsage() {
        NSWorkspace.shared.open(URL(string: "https://chatgpt.com/codex/settings/usage")!)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.menuBarRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshCurrentSession()
            }
        }
    }

    private func preferredMenuBarWindow(in snapshot: RateLimitSnapshot) -> RateLimitWindow? {
        if snapshot.primary?.windowDurationMins == 300 {
            return snapshot.primary
        }
        if snapshot.secondary?.windowDurationMins == 300 {
            return snapshot.secondary
        }

        let windows = [snapshot.primary, snapshot.secondary].compactMap { $0 }
        return windows.min { lhs, rhs in
            menuBarWindowDistance(for: lhs) < menuBarWindowDistance(for: rhs)
        }
    }

    private func menuBarWindowDistance(for window: RateLimitWindow) -> Int64 {
        guard let duration = window.windowDurationMins else { return .max }
        return abs(duration - 300)
    }

    private func cleanupIncompleteProfiles() {
        let incompleteProfiles = store.database.profiles.filter { profile in
            guard profile.accountIDHash == nil, profile.email == nil else { return false }
            let codexHome = URL(fileURLWithPath: profile.codexHomePath, isDirectory: true)
            return (try? authFileManager.accountIDHash(codexHome: codexHome)) == nil
        }

        for profile in incompleteProfiles {
            if let removed = try? store.removeProfile(id: profile.id) {
                try? authFileManager.deleteCodexHome(URL(fileURLWithPath: removed.codexHomePath, isDirectory: true))
            }
        }
    }

    private func cleanupTemporaryProfiles() {
        try? authFileManager.deleteCodexHome(paths.temporaryProfilesDirectory)
        try? FileSecurity.ensurePrivateDirectory(paths.temporaryProfilesDirectory)
    }

    private func readAccountForCurrentCodexHome() async throws -> AccountInfo {
        let client = try CodexAppServerClient(codexHome: paths.currentCodexHome)
        defer { client.stop() }
        try client.start()
        try await client.initialize()
        return try await accountService.readAccount(using: client)
    }
}

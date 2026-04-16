import AppKit
import CodexManagerCore
import SwiftUI

@MainActor
final class AddAccountViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case waiting(LoginStartInfo)
        case finishing
        case completed(String)
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var switchAfterAdding = false

    private let appModel: AppViewModel
    private var client: CodexAppServerClient?
    private var loginInfo: LoginStartInfo?
    private var temporaryHome: URL?
    private var finalProfileID: String?
    private var finished = false
    private var isFinishing = false

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    func start() {
        guard case .idle = state else { return }
        state = .starting

        Task {
            do {
                let profileID = UUID().uuidString
                finalProfileID = profileID
                let (info, client) = try await appModel.codexAccountService.startDeviceLogin(profileID: profileID)
                self.client = client
                self.loginInfo = info
                self.temporaryHome = info.temporaryCodexHome
                client.notificationHandler = { [weak self] method, _ in
                    guard method == "account/login/completed" else { return }
                    Task { @MainActor in
                        self?.finish()
                    }
                }
                state = .waiting(info)
                pollForCompletion()
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func finish() {
        guard !finished, !isFinishing else { return }
        guard let client, let loginInfo, let temporaryHome, let finalProfileID else {
            state = .failed("Login session was not initialized.")
            return
        }
        isFinishing = true
        state = .finishing

        Task {
            do {
                let account = try await appModel.codexAccountService.readAccount(using: client, refreshToken: true)
                let authManager = AuthFileManager(paths: appModel.codexPaths)
                guard !account.requiresOpenAIAuth,
                      let hash = try authManager.accountIDHash(codexHome: temporaryHome) else {
                    isFinishing = false
                    state = .waiting(loginInfo)
                    return
                }

                finished = true
                let usage = try? await appModel.codexAccountService.readRateLimits(using: client)
                if let existing = appModel.profileStore.profile(accountIDHash: hash),
                   existing.id != finalProfileID {
                    try authManager.moveTemporaryCodexHome(
                        temporaryHome,
                        to: URL(fileURLWithPath: existing.codexHomePath, isDirectory: true)
                    )
                    var updated = existing
                    updated.email = account.email
                    updated.planType = account.planType
                    updated.accountIDHash = hash
                    updated.lastUsageSnapshot = usage?.preferredCodexSnapshot
                    updated.lastRefreshedAt = usage == nil ? existing.lastRefreshedAt : Date()
                    try appModel.profileStore.upsert(updated)
                    state = .completed("Updated \(updated.displayName).")
                    appModel.reload()
                    client.stop()
                    return
                }

                let profile = try appModel.codexAccountService.finalizeLogin(
                    temporaryCodexHome: temporaryHome,
                    finalProfileID: finalProfileID,
                    accountInfo: account,
                    usage: usage
                )

                try appModel.profileStore.upsert(profile)
                client.stop()
                if switchAfterAdding {
                    appModel.switchToProfile(profile)
                } else {
                    appModel.reload()
                }
                state = .completed("Added \(profile.displayName).")
            } catch {
                isFinishing = false
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        guard !finished else { return }
        isFinishing = false
        client?.stop()
        if let temporaryHome {
            try? AuthFileManager(paths: appModel.codexPaths).deleteCodexHome(
                temporaryHome.deletingLastPathComponent()
            )
        }
    }

    private func pollForCompletion() {
        Task {
            while !finished {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !finished, let client else { return }
                if let account = try? await appModel.codexAccountService.readAccount(using: client, refreshToken: true),
                   account.email != nil {
                    finish()
                    return
                }
            }
        }
    }
}

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddAccountViewModel
    @EnvironmentObject private var appModel: AppViewModel

    init(appModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: AddAccountViewModel(appModel: appModel))
    }

    var body: some View {
        content
        .padding(22)
        .frame(width: 390, height: 230, alignment: .topLeading)
        .onDisappear {
            viewModel.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleContent
        case .starting:
            progressContent(message: appModel.strings.text(.startingLogin))
        case let .waiting(info):
            VStack(alignment: .center, spacing: 12) {
                Text(appModel.strings.text(.addAccountTitle))
                    .font(.title2.weight(.semibold))
                Text(appModel.strings.text(.code))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(info.userCode)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
                Link(appModel.strings.text(.openVerificationPage), destination: info.verificationURL)
                ProgressView(appModel.strings.text(.waitingForLogin))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .finishing:
            progressContent(message: appModel.strings.text(.savingAccount))
        case let .completed(message):
            VStack(spacing: 18) {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button(appModel.strings.text(.done)) {
                    closeCurrentWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            VStack(alignment: .center, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Button(appModel.strings.text(.tryAgain)) {
                    viewModel.cancel()
                    viewModel.state = .idle
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var idleContent: some View {
        VStack(spacing: 18) {
            Text(appModel.strings.text(.addAccountTitle))
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            Text(appModel.strings.text(.addAccountDescription))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity, minHeight: 74)

            HStack(alignment: .center) {
                Toggle(appModel.strings.text(.switchAfterAdding), isOn: $viewModel.switchAfterAdding)
                    .font(.system(size: 13, weight: .regular))
                    .toggleStyle(.checkbox)

                Spacer()

                Button(appModel.strings.text(.cancel)) {
                    viewModel.cancel()
                    closeCurrentWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    viewModel.start()
                } label: {
                    Text(appModel.strings.text(.signInWithChatGPT))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func progressContent(message: String) -> some View {
        VStack(spacing: 16) {
            Text(appModel.strings.text(.addAccountTitle))
                .font(.title2.weight(.semibold))
            ProgressView(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func closeCurrentWindow() {
        dismiss()
    }
}

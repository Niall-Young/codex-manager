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
                guard let hash = try authManager.accountIDHash(codexHome: temporaryHome) else {
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
                    if updated.email == nil, let email = account.email {
                        updated.email = email
                        updated.displayName = email
                    }
                    updated.planType = account.planType
                    updated.accountIDHash = hash
                    updated.lastUsageSnapshot = usage?.preferredCodexSnapshot
                    updated.lastRefreshedAt = usage == nil ? existing.lastRefreshedAt : Date()
                    try appModel.profileStore.upsert(updated)
                    if switchAfterAdding {
                        appModel.switchToProfile(updated)
                    } else {
                        appModel.reload()
                        appModel.refreshCurrentSession()
                    }
                    let message = appModel.strings.text(.accountAlreadyManaged)
                    appModel.statusMessage = message
                    state = .completed(message)
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
                    appModel.refreshCurrentSession()
                }
                let message = appModel.strings.text(.addedAccountMessage)
                appModel.statusMessage = message
                state = .completed(message)
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
    @State private var hostingWindow: NSWindow?
    @State private var copiedCode = false

    init(appModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: AddAccountViewModel(appModel: appModel))
    }

    var body: some View {
        content
        .padding(22)
        .frame(width: 460, height: 320, alignment: .topLeading)
        .background(AddAccountWindowAccessor(window: $hostingWindow))
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
            waitingContent(info)
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
        VStack(alignment: .leading, spacing: 18) {
            statusIcon(systemName: "person.badge.plus", tint: .blue)

            Text(appModel.strings.text(.addAccountDescription))
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)

            Text(appModel.strings.text(.addAccountTitle))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                switchAfterAddingToggle
                Spacer()
                dialogButtons(
                    secondaryTitle: appModel.strings.text(.cancel),
                    primaryTitle: appModel.strings.text(.signInWithChatGPT),
                    secondaryAction: {
                        viewModel.cancel()
                        closeCurrentWindow()
                    },
                    primaryAction: {
                        viewModel.start()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func waitingContent(_ info: LoginStartInfo) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            statusIcon(systemName: "key.viewfinder", tint: .yellow)

            Text(appModel.strings.text(.finishSignInTitle))
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)

            Text(appModel.strings.text(.finishSignInDescription))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.strings.text(.code))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(info.userCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                }
                Spacer()
                Button(copiedCode ? appModel.strings.text(.copiedCode) : appModel.strings.text(.copyCode)) {
                    copyCode(info.userCode)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                copyCode(info.userCode)
            }

            Button {
                openVerificationPage(info)
            } label: {
                Text(appModel.strings.text(.openVerificationPage))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(appModel.strings.text(.waitingForLogin))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center, spacing: 12) {
                switchAfterAddingToggle
                Spacer()

                Button(appModel.strings.text(.cancel)) {
                    viewModel.cancel()
                    closeCurrentWindow()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func progressContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            statusIcon(systemName: "arrow.triangle.2.circlepath", tint: .blue)
            Text(appModel.strings.text(.addAccountTitle))
                .font(.system(size: 21, weight: .semibold))
            ProgressView(message)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func statusIcon(systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: 62, height: 62)
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func dialogButtons(
        secondaryTitle: String,
        primaryTitle: String,
        secondaryAction: @escaping () -> Void,
        primaryAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Button(secondaryTitle, action: secondaryAction)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .frame(width: 84)

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(width: 84)
        }
    }

    private var switchAfterAddingToggle: some View {
        Toggle(appModel.strings.text(.switchAfterAdding), isOn: $viewModel.switchAfterAdding)
            .font(.system(size: 13, weight: .regular))
            .toggleStyle(.checkbox)
    }

    private func copyCode(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copiedCode = true
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                copiedCode = false
            }
        }
    }

    private func openVerificationPage(_ info: LoginStartInfo) {
        copyCode(info.userCode)
        NSWorkspace.shared.open(info.verificationURL)
        hostingWindow?.orderFrontRegardless()
    }

    private func closeCurrentWindow() {
        if let hostingWindow {
            hostingWindow.close()
            return
        }
        dismiss()
    }
}

private struct AddAccountWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            window = view.window
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            window = view.window
        }
    }
}

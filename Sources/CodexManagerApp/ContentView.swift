import AppKit
import CodexManagerCore
import SwiftUI
import Combine

private enum AppTypography {
    static let title = Font.system(size: 15, weight: .medium)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    static let smallBadge = Font.system(size: 13, weight: .bold)
}

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var showingInlineSettings = false
    private let refreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if showingInlineSettings {
                settingsPanel
            } else {
                mainPanel
            }
        }
        .padding(18)
        .frame(width: 420, alignment: .topLeading)
        .onAppear {
            model.reload()
            model.refreshCurrentSession()
        }
        .onReceive(refreshTimer) { _ in
            model.refreshCurrentSession()
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            profileList
            actions
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.strings.text(.appTitle))
                    .font(AppTypography.title)
                Spacer()
            }

            if let active = model.displayedCurrentProfile {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.linearGradient(
                                colors: [Color.accentColor.opacity(0.35), Color.white.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(active.displayName)
                            .font(AppTypography.title)
                            .lineLimit(1)
                        Text(active.email ?? model.strings.text(.noEmail))
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    planBadge(active.planType)
                }
                UsageSnapshotView(snapshot: active.lastUsageSnapshot)
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppTypography.body)
                    Text(model.strings.text(.localEstimate))
                    Spacer()
                    Text("\(model.localUsage.tokensUsed.formatted()) \(model.strings.text(.tokens))")
                    Text("·")
                    Text("\(model.localUsage.threadCount) \(model.strings.text(.threads))")
                }
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            } else {
                EmptyStateView(
                    title: model.strings.text(.noActiveAccount),
                    subtitle: model.strings.text(.noActiveSubtitle)
                )
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    showingInlineSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(GlassIconButtonStyle())
                .help("Back")

                Text(model.strings.text(.preferences))
                    .font(AppTypography.title)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 18) {
                settingsCard(title: model.strings.text(.appearance)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.strings.text(.language))
                            .font(AppTypography.title)
                        Picker(model.strings.text(.language), selection: $model.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }

                settingsCard(title: model.strings.text(.dataLocation)) {
                    SettingsPathRow(title: model.strings.text(.codexHome), url: model.codexPaths.currentCodexHome)
                    SettingsPathRow(title: "App Support", url: model.codexPaths.applicationSupportDirectory)
                }
            }
        }
    }

    private var profileList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.strings.text(.accounts))
                    .font(AppTypography.title)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    AppWindowCoordinator.shared.showAddAccount(model: model)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(model.strings.text(.addAccount))
            }

            if model.profiles.isEmpty {
                EmptyStateView(
                    title: model.strings.text(.noManagedAccounts),
                    subtitle: model.strings.text(.noManagedSubtitle)
                )
            } else {
                if let currentSessionProfile = model.currentSessionProfile {
                    CurrentSessionRow(
                        profile: currentSessionProfile,
                        strings: model.strings,
                        importAction: { model.importCurrentAccount() }
                    )
                }
                ForEach(model.profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        isActive: profile.id == model.currentProfileID,
                        strings: model.strings,
                        switchAction: { model.switchToProfile(profile) },
                        refreshAction: { model.refreshUsage(for: profile) },
                        deleteAction: { model.deleteProfile(profile) }
                    )
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                model.importCurrentAccount()
            } label: {
                Label(model.strings.text(.importCurrent), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(GlassActionButtonStyle())
            Button {
                showingInlineSettings = true
            } label: {
                Label(model.strings.text(.settings), systemImage: "gearshape")
            }
            .buttonStyle(GlassActionButtonStyle())
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(GlassIconButtonStyle())
            .help(model.strings.text(.quit))
        }
        .labelStyle(.titleAndIcon)
    }

    private func planBadge(_ plan: String?) -> some View {
        Text((plan ?? "unknown").uppercased())
            .font(AppTypography.smallBadge)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.10))
            }
    }
}

struct SettingsPathRow: View {
    let title: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.title)
                        .foregroundStyle(.primary)
                    Text(url.path)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "folder")
                    .font(AppTypography.title)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open in Finder")
    }
}

@ViewBuilder
private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(AppTypography.title)
            .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
    }
}

struct ProfileRow: View {
    let profile: ManagedProfile
    let isActive: Bool
    let strings: Strings
    let switchAction: () -> Void
    let refreshAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.16) : Color.primary.opacity(0.06))
                Image(systemName: isActive ? "checkmark" : "person")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? .green : .secondary)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(AppTypography.title)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(profile.email ?? strings.text(.notVerified))
                    if let snapshot = profile.lastUsageSnapshot,
                       let remaining = snapshot.primary?.remainingPercent {
                        Text("\(remaining)%")
                    }
                }
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: refreshAction) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(GlassIconButtonStyle(size: 26))
            .help(strings.text(.refreshUsage))
            Button(action: switchAction) {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(GlassIconButtonStyle(size: 26))
            .help(strings.text(.switchAccount))
            Button(role: .destructive, action: deleteAction) {
                Image(systemName: "trash")
            }
            .buttonStyle(GlassIconButtonStyle(size: 26))
            .help(strings.text(.deleteLocalProfile))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isActive ? Color.white.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct CurrentSessionRow: View {
    let profile: ManagedProfile
    let strings: Strings
    let importAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(AppTypography.title)
                    .lineLimit(1)
                Text("当前会话，尚未加入托管列表")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: importAction) {
                Label(strings.text(.importCurrent), systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(GlassIconButtonStyle(size: 26))
            .help(strings.text(.importCurrent))
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.22))
        }
    }
}

struct UsageSnapshotView: View {
    @EnvironmentObject private var model: AppViewModel
    let snapshot: RateLimitSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let snapshot {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.strings.text(.remainingQuota))
                            .font(AppTypography.title)
                            .foregroundStyle(.secondary)
                        if let credits = snapshot.credits, credits.hasCredits || credits.unlimited {
                            Text("\(model.strings.text(.credits)): \(credits.unlimited ? model.strings.text(.unlimited) : (credits.balance ?? "0"))")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Text(snapshot.limitName ?? snapshot.limitId ?? "codex")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.055), in: Capsule())
                }

                VStack(spacing: 8) {
                    if let primary = snapshot.primary {
                        usageLine(title: label(for: primary, fallback: model.strings.text(.primary)), window: primary)
                    }
                    if let secondary = snapshot.secondary {
                        usageLine(title: label(for: secondary, fallback: model.strings.text(.secondary)), window: secondary)
                    }
                }
            } else {
                Text(model.strings.text(.usageNotRefreshed))
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
    }

    private func usageLine(title: String, window: RateLimitWindow) -> some View {
        let tint = quotaTint(for: window.remainingPercent)

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(AppTypography.title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(window.remainingPercent)%")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(tint)
                if let reset = resetTime(for: window) {
                    Text(reset)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(tint)
                .controlSize(.small)
        }
    }

    private func quotaTint(for remainingPercent: Int) -> Color {
        switch remainingPercent {
        case 51...:
            return .green
        case 30...50:
            return .blue
        case 10..<30:
            return .yellow
        default:
            return .red
        }
    }

    private func label(for window: RateLimitWindow, fallback: String) -> String {
        guard let minutes = window.windowDurationMins, minutes > 0 else { return fallback }
        switch model.language {
        case .english:
            if minutes % (60 * 24 * 7) == 0 {
                return "\(minutes / (60 * 24 * 7))w"
            }
            if minutes % (60 * 24) == 0 {
                return "\(minutes / (60 * 24))d"
            }
            if minutes % 60 == 0 {
                return "\(minutes / 60)h"
            }
            return "\(minutes)m"
        case .chinese:
            if minutes % (60 * 24 * 7) == 0 {
                return "\(minutes / (60 * 24 * 7))周"
            }
            if minutes % (60 * 24) == 0 {
                return "\(minutes / (60 * 24))天"
            }
            if minutes % 60 == 0 {
                return "\(minutes / 60)小时"
            }
            return "\(minutes)分钟"
        }
    }

    private func resetTime(for window: RateLimitWindow) -> String? {
        guard let resetsAt = window.resetsAt else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(resetsAt))
            .formatted(.dateTime.hour().minute())
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppTypography.title)
            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GlassActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10))
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.18 : 0.09))
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

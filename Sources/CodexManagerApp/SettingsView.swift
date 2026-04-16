import CodexManagerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var selectedProfileID: ManagedProfile.ID?
    @State private var draftName = ""

    var selectedProfile: ManagedProfile? {
        model.profiles.first { $0.id == selectedProfileID } ?? model.profiles.first
    }

    var body: some View {
        NavigationSplitView {
            List(model.profiles, selection: $selectedProfileID) { profile in
                VStack(alignment: .leading) {
                    Text(profile.displayName)
                    Text(profile.email ?? "No email")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(model.strings.text(.accounts))
        } detail: {
            if let profile = selectedProfile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        settingsSection(model.strings.text(.appearance)) {
                            Picker(model.strings.text(.language), selection: $model.language) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        settingsSection(model.strings.text(.accountManagement)) {
                            TextField(model.strings.text(.displayName), text: $draftName)
                                .onAppear { draftName = profile.displayName }
                            HStack {
                                Button(model.strings.text(.saveName)) {
                                    model.renameProfile(profile, displayName: draftName)
                                }
                                Button(model.strings.text(.refresh)) {
                                    model.refreshUsage(for: profile)
                                }
                                Button(model.strings.text(.switchTitle)) {
                                    model.switchToProfile(profile)
                                }
                            }
                        }

                        settingsSection(model.strings.text(.usageExplanationTitle)) {
                            UsageExplanationRow(title: model.strings.text(.credits), text: model.strings.text(.creditsExplanation))
                            UsageExplanationRow(title: model.strings.text(.primary), text: model.strings.text(.primaryExplanation))
                            UsageExplanationRow(title: model.strings.text(.secondary), text: model.strings.text(.secondaryExplanation))
                            UsageExplanationRow(title: model.strings.text(.localEstimate), text: model.strings.text(.localEstimateExplanation))
                        }

                        settingsSection(model.strings.text(.dataLocation)) {
                            LabeledContent(model.strings.text(.email), value: profile.email ?? "Unknown")
                            LabeledContent(model.strings.text(.plan), value: profile.planType ?? "Unknown")
                            LabeledContent(model.strings.text(.profileID), value: profile.id)
                            LabeledContent(model.strings.text(.codexHome), value: profile.codexHomePath)
                            if let refreshed = profile.lastRefreshedAt {
                                LabeledContent(model.strings.text(.lastRefresh), value: refreshed.formatted(date: .abbreviated, time: .shortened))
                            }
                            UsageSnapshotView(snapshot: profile.lastUsageSnapshot)
                                .environmentObject(model)
                            HStack {
                                Button(model.strings.text(.deleteLocalProfile), role: .destructive) {
                                    model.deleteProfile(profile)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .navigationTitle(profile.displayName)
            } else {
                Text("No account selected")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 780, minHeight: 460)
        .onAppear {
            selectedProfileID = selectedProfileID ?? model.profiles.first?.id
            draftName = selectedProfile?.displayName ?? ""
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            }
        }
    }
}

struct UsageExplanationRow: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}

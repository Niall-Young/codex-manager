import SwiftUI

@main
struct CodexManagerApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
        } label: {
            MenuBarStatusLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusLabel: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: "arrow.triangle.swap")
                .symbolRenderingMode(.monochrome)
                .imageScale(.small)
                .font(.system(size: 12, weight: .regular))
                .frame(width: 12, height: 12, alignment: .center)
            Text(model.menuBarQuotaText)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
        .frame(height: 16)
        .foregroundStyle(.primary)
    }
}

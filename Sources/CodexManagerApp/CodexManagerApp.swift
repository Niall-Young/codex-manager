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
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 11, weight: .regular))
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
            Text(model.menuBarQuotaText)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
    }
}

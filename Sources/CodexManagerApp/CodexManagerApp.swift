import SwiftUI

@main
struct CodexManagerApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        MenuBarExtra("Codex Manager", systemImage: "arrow.triangle.swap") {
            ContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

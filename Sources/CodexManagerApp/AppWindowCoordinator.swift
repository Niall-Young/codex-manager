import AppKit
import SwiftUI

@MainActor
final class AppWindowCoordinator {
    static let shared = AppWindowCoordinator()

    private var settingsWindowController: NSWindowController?
    private var addAccountWindowController: NSWindowController?

    private init() {}

    func showSettings(model: AppViewModel) {
        let rootView = SettingsView()
            .environmentObject(model)

        let controller = ensureWindowController(
            existing: settingsWindowController,
            title: model.strings.text(.preferences),
            size: NSSize(width: 860, height: 580),
            rootView: AnyView(rootView)
        )
        settingsWindowController = controller
        present(controller)
    }

    func showAddAccount(model: AppViewModel) {
        let rootView = AddAccountView(appModel: model)
            .environmentObject(model)

        let controller = ensureWindowController(
            existing: addAccountWindowController,
            title: model.strings.text(.addAccountTitle),
            size: NSSize(width: 460, height: 320),
            resizable: false,
            rootView: AnyView(rootView)
        )
        addAccountWindowController = controller
        present(controller)
    }

    private func ensureWindowController(
        existing: NSWindowController?,
        title: String,
        size: NSSize,
        resizable: Bool = true,
        rootView: AnyView
    ) -> NSWindowController {
        if let existing, let window = existing.window {
            window.title = title
            if let hosting = window.contentViewController as? NSHostingController<AnyView> {
                hosting.rootView = rootView
            } else {
                window.contentViewController = NSHostingController(rootView: rootView)
            }
            window.styleMask = resizable
                ? [.titled, .closable, .miniaturizable, .resizable]
                : [.titled, .closable, .miniaturizable]
            return existing
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: resizable
                ? [.titled, .closable, .miniaturizable, .resizable]
                : [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.center()
        window.setFrameAutosaveName("CodexManager.\(title)")
        window.contentViewController = NSHostingController(rootView: rootView)
        return NSWindowController(window: window)
    }

    private func present(_ controller: NSWindowController) {
        guard let window = controller.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

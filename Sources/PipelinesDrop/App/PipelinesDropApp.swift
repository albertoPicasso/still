import SwiftUI

@main
struct PipelinesDropApp: App {
    @State private var container: AppContainer

    init() {
        let container = AppContainer(persistence: DebugCommands.isActive
            ? InMemoryProfilePersistence()
            : UserDefaultsProfilePersistence())
        _container = State(initialValue: container)

        if DebugCommands.isActive {
            DebugCommands.run(container)
        } else {
            Task { await container.status.bootstrap() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: container.status)
        } label: {
            Image(nsImage: MenuBarIcon.image(container.status.menuBarStates))
        }
        .menuBarExtraStyle(.window)

        Window("Pipelines Drop", id: SettingsView.windowID) {
            SettingsView(viewModel: container.settings)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

// Raíz de composición: crea los servicios y los inyecta en los ViewModels
@MainActor
final class AppContainer {
    let preferences: AppPreferences
    let store: ProfileStore
    let github: GitHubService
    let status: StatusViewModel
    let settings: SettingsViewModel

    init(persistence: ProfilePersistence, github: GitHubService = GitHubClient()) {
        preferences = AppPreferences()
        store = ProfileStore(persistence: persistence)
        self.github = github
        status = StatusViewModel(store: store, github: github, preferences: preferences)
        settings = SettingsViewModel(store: store, github: github, preferences: preferences)
    }
}

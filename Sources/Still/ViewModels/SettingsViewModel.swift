import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    enum Selection: Hashable { case profile(UUID), general }

    var selection: Selection?
    private(set) var owners: [String] = []

    @ObservationIgnored let store: ProfileStore
    @ObservationIgnored let preferences: AppPreferences
    @ObservationIgnored private let github: GitHubService
    @ObservationIgnored private var editors: [UUID: ProfileEditorViewModel] = [:]

    init(store: ProfileStore, github: GitHubService, preferences: AppPreferences) {
        self.store = store
        self.github = github
        self.preferences = preferences
    }

    var profiles: [Profile] { store.profiles }

    func isActive(_ id: UUID) -> Bool { store.activeID == id }

    var selectedProfileID: UUID? {
        if case .profile(let id) = selection, store.profile(id) != nil { return id }
        return nil
    }

    var canRemove: Bool { selectedProfileID != nil }

    func onAppear() async {
        if selection == nil, let id = store.activeID ?? store.profiles.first?.id { selection = .profile(id) }
        if owners.isEmpty { owners = (try? await github.owners()) ?? [] }
    }

    func addProfile() {
        let p = store.add(owner: owners.first ?? "")
        selection = .profile(p.id)
    }

    func removeSelected() {
        guard let id = selectedProfileID else { return }
        store.remove(id)
        editors[id] = nil
        selection = store.profiles.first.map { .profile($0.id) }
    }

    // Un editor por perfil, para no perder la lista de repos al cambiar de selección
    func editor(for id: UUID) -> ProfileEditorViewModel {
        if let e = editors[id] { return e }
        let e = ProfileEditorViewModel(profileID: id, store: store, github: github)
        editors[id] = e
        return e
    }
}

import Foundation
import Observation

@Observable
@MainActor
final class ProfileEditorViewModel {
    let profileID: UUID
    private(set) var repos: [Repo] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    var search = ""

    @ObservationIgnored private let store: ProfileStore
    @ObservationIgnored private let github: GitHubService
    @ObservationIgnored private var loadedOwner: String?

    init(profileID: UUID, store: ProfileStore, github: GitHubService) {
        self.profileID = profileID
        self.store = store
        self.github = github
    }

    private var profile: Profile { store.profile(profileID) ?? Profile(name: "", owner: "") }

    // MARK: Campos editables

    var name: String {
        get { profile.name }
        set { store.update(profileID) { $0.name = newValue } }
    }

    var owner: String {
        get { profile.owner }
        set { store.update(profileID) { $0.owner = newValue } }
    }

    var environments: [EnvConfig] {
        get { profile.environments }
        set { store.update(profileID) { $0.environments = newValue } }
    }

    var isActive: Bool { store.activeID == profileID }

    func activate() { store.activeID = profileID }

    func ownerOptions(from owners: [String]) -> [String] {
        owner.isEmpty || owners.contains(owner) ? owners : [owner] + owners
    }

    // MARK: Entornos

    var canAddEnvironment: Bool { environments.count < Profile.maxEnvironments }

    func addEnvironment() {
        guard canAddEnvironment else { return }
        environments.append(EnvConfig(name: "ENV", branch: ""))
    }

    func removeEnvironment(_ id: UUID) {
        environments.removeAll { $0.id == id }
    }

    // MARK: Repos

    var filteredRepos: [Repo] {
        search.isEmpty ? repos : repos.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var watchedCount: Int { profile.repos.count }

    func isWatched(_ name: String) -> Bool { profile.repos.contains(name) }

    func setWatched(_ name: String, _ on: Bool) {
        store.update(profileID) { p in
            if on {
                if !p.repos.contains(name) { p.repos = (p.repos + [name]).sorted() }
            } else {
                p.repos.removeAll { $0 == name }
            }
        }
    }

    func watchAllFiltered() {
        let names = filteredRepos.map(\.name)
        store.update(profileID) { $0.repos = Array(Set($0.repos + names)).sorted() }
    }

    func watchNoneFiltered() {
        let names = Set(filteredRepos.map(\.name))
        store.update(profileID) { $0.repos.removeAll(where: names.contains) }
    }

    func loadRepos() async {
        let owner = owner
        guard owner != loadedOwner else { return }
        guard !owner.isEmpty else {
            repos = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            repos = try await github.repos(owner: owner)
            loadedOwner = owner
            loadError = nil
        } catch {
            repos = []
            loadError = error.localizedDescription
        }
    }
}

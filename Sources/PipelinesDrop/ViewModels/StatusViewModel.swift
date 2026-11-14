import Foundation
import Observation

// Estado del semáforo y bucle de consulta. Lo usan el icono y el desplegable.
@Observable
@MainActor
final class StatusViewModel {
    enum Hint: Equatable { case noProfile, noRepos }

    private(set) var statuses: [UUID: EnvStatus] = [:]
    private(set) var errorMessage: String?
    private(set) var lastUpdate: Date?

    @ObservationIgnored let store: ProfileStore
    @ObservationIgnored private let github: GitHubService
    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastKey: Profile.PollingKey?

    init(store: ProfileStore, github: GitHubService, preferences: AppPreferences) {
        self.store = store
        self.github = github
        self.preferences = preferences
    }

    // MARK: Salidas para la vista

    var environments: [EnvConfig] { store.active?.environments ?? [] }

    var menuBarStates: [EnvState] { environments.map { status(for: $0).state } }

    var hint: Hint? {
        guard let p = store.active else { return .noProfile }
        return p.repos.isEmpty ? .noRepos : nil
    }

    var profiles: [Profile] { store.profiles }

    var activeProfileID: UUID? {
        get { store.activeID }
        set { store.activeID = newValue }
    }

    var activeProfileName: String { store.active?.name ?? "" }

    var ownerURL: URL? {
        guard let owner = store.active?.owner, !owner.isEmpty else { return nil }
        return URL(string: "https://github.com/\(owner)")
    }

    func status(for env: EnvConfig) -> EnvStatus { statuses[env.id] ?? EnvStatus() }

    // MARK: Ciclo de vida

    // Primer arranque: crea un perfil con el usuario de gh
    func bootstrap() async {
        if store.profiles.isEmpty, let me = try? await github.owners().first {
            store.add(owner: me)
        }
        lastKey = store.active?.pollingKey
        observeProfile()
        restart()
    }

    func refreshNow() {
        Task { await github.resetSession() }
        restart()
    }

    func refreshOnce() async { await refresh() }

    // MARK: Interno

    private func restart(after delay: Duration = .zero) {
        loop?.cancel()
        loop = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.preferences.pollInterval))
            }
        }
    }

    // Se relanza solo si cambia lo que afecta a la consulta
    private func observeProfile() {
        withObservationTracking {
            _ = store.active?.pollingKey
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let key = self.store.active?.pollingKey
                if key != self.lastKey {
                    self.lastKey = key
                    self.statuses = [:]
                    self.errorMessage = nil
                    self.restart(after: .milliseconds(800))
                }
                self.observeProfile()
            }
        }
    }

    private func refresh() async {
        guard let profile = store.active, !profile.repos.isEmpty else {
            errorMessage = nil
            return
        }
        do {
            let window = preferences.failureWindow
            var result: [UUID: EnvStatus] = [:]
            for env in profile.environments {
                let runs = try await fetchRuns(owner: profile.owner, repos: profile.repos, branch: env.branch)
                result[env.id] = StatusCalculator.status(runsByRepo: runs, workflowFilter: env.workflowFilter,
                                                         failureWindow: window)
            }
            guard !Task.isCancelled, store.active?.pollingKey == profile.pollingKey else { return }
            statuses = result
            lastUpdate = Date()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchRuns(owner: String, repos: [String], branch: String) async throws -> [(repo: String, runs: [WorkflowRun])] {
        let branch = branch.trimmingCharacters(in: .whitespaces)
        guard !branch.isEmpty else { return [] }
        let github = github
        return try await withThrowingTaskGroup(of: (repo: String, runs: [WorkflowRun]).self) { group in
            for repo in repos {
                group.addTask {
                    do {
                        return (repo, try await github.runs(owner: owner, repo: repo, branch: branch))
                    } catch GitHubError.http(404, _) {
                        return (repo, [])  // repo borrado o sin Actions
                    }
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }

    // MARK: Diagnóstico

    func loadDemo() {
        let url = URL(string: "https://github.com")!
        guard environments.count >= 2 else { return }
        statuses[environments[0].id] = EnvStatus(state: .busy, active: [
            ActiveRun(id: 1, repo: "api", workflow: "Deploy to DEV", actor: "dev",
                      startedAt: Date().addingTimeInterval(-154), queued: false, expectedDuration: 300, url: url),
            ActiveRun(id: 2, repo: "web", workflow: "Deploy web to DEV", actor: "dev",
                      startedAt: Date().addingTimeInterval(-41), queued: false, expectedDuration: 420, url: url),
        ])
        statuses[environments[1].id] = EnvStatus(state: .failed, failure: FinishedRun(
            repo: "api", workflow: "Deploy to PRODUCTION",
            finishedAt: Date().addingTimeInterval(-360), success: false, url: url))
    }

    var debugDescription: String {
        guard let p = store.active else { return "sin perfil configurado" }
        var out = "perfil: \(p.name) · \(p.owner) · \(p.repos.count) repos\n"
        if let errorMessage { out += "error: \(errorMessage)\n" }
        for env in p.environments {
            let s = status(for: env)
            out += "\(env.name) (\(env.branch)): \(s.state)\n"
            for r in s.active {
                let t = r.queued ? "en cola" : Formatters.clock(Date().timeIntervalSince(r.startedAt ?? Date()))
                out += "  · \(r.repo) [\(r.workflow)] \(t) esperado=\(r.expectedDuration.map(Formatters.clock) ?? "?")\n"
            }
            if let d = s.lastDeploy { out += "  último: \(d.repo) [\(d.workflow)] \(d.success ? "ok" : "fallo") \(Formatters.relative(d.finishedAt))\n" }
            if let f = s.failure { out += "  fallo: \(f.repo) [\(f.workflow)] \(Formatters.relative(f.finishedAt))\n" }
        }
        return out
    }
}

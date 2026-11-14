import Foundation
import Observation

protocol ProfilePersistence {
    func load() -> (profiles: [Profile], activeID: UUID?)
    func save(profiles: [Profile], activeID: UUID?)
}

struct UserDefaultsProfilePersistence: ProfilePersistence {
    private let defaults: UserDefaults
    private let profilesKey = "profiles"
    private let activeKey = "activeProfile"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> (profiles: [Profile], activeID: UUID?) {
        let profiles = defaults.data(forKey: profilesKey)
            .flatMap { try? JSONDecoder().decode([Profile].self, from: $0) } ?? []
        return (profiles, defaults.string(forKey: activeKey).flatMap(UUID.init))
    }

    func save(profiles: [Profile], activeID: UUID?) {
        defaults.set(try? JSONEncoder().encode(profiles), forKey: profilesKey)
        defaults.set(activeID?.uuidString, forKey: activeKey)
    }
}

// Para los modos de diagnóstico y los tests: no toca lo guardado
struct InMemoryProfilePersistence: ProfilePersistence {
    var initial: [Profile] = []
    func load() -> (profiles: [Profile], activeID: UUID?) { (initial, initial.first?.id) }
    func save(profiles: [Profile], activeID: UUID?) {}
}

// Fuente de verdad de los perfiles, compartida por los ViewModels
@Observable
@MainActor
final class ProfileStore {
    private(set) var profiles: [Profile]
    var activeID: UUID? {
        didSet { persist() }
    }

    @ObservationIgnored private let persistence: ProfilePersistence

    init(persistence: ProfilePersistence) {
        self.persistence = persistence
        let saved = persistence.load()
        profiles = saved.profiles
        activeID = saved.activeID.flatMap { id in saved.profiles.contains { $0.id == id } ? id : nil }
            ?? saved.profiles.first?.id
    }

    var active: Profile? { profiles.first { $0.id == activeID } }

    func profile(_ id: UUID) -> Profile? { profiles.first { $0.id == id } }

    @discardableResult
    func add(owner: String) -> Profile {
        let p = Profile(name: owner.isEmpty ? "Perfil \(profiles.count + 1)" : owner, owner: owner)
        profiles.append(p)
        if activeID == nil { activeID = p.id }
        persist()
        return p
    }

    func remove(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeID == id { activeID = profiles.first?.id }
        persist()
    }

    func update(_ id: UUID, _ change: (inout Profile) -> Void) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        change(&profiles[i])
        persist()
    }

    private func persist() {
        persistence.save(profiles: profiles, activeID: activeID)
    }
}
